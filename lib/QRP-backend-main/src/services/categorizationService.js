/**
 * Categorization Service
 * Provides rule-based keyword matching for auto-detecting defect categories
 * from reviewer remarks
 */

/**
 * Normalize text for comparison
 * - Convert to lowercase
 * - Remove punctuation
 * - Trim whitespace
 */
function normalizeText(text) {
  if (!text || typeof text !== "string") return "";
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, "") // Remove punctuation
    .trim();
}

/**
 * Extract words and phrases from text
 * Returns both individual words and common multi-word phrases
 */
function extractTokens(text) {
  const normalized = normalizeText(text);
  if (!normalized) return [];

  const words = normalized.split(/\s+/);

  // Create tokens: individual words + some 2-word phrases
  const tokens = [...words];
  for (let i = 0; i < words.length - 1; i++) {
    tokens.push(`${words[i]} ${words[i + 1]}`);
  }

  return tokens.filter((t) => t.length > 0);
}

/**
 * Calculate keyword matches between remark tokens and category keywords
 * Returns match count
 */
function countKeywordMatches(tokens, categoryKeywords) {
  if (!categoryKeywords || categoryKeywords.length === 0) return 0;

  const normalizedCategoryKeywords = categoryKeywords.map(normalizeText);
  let matchCount = 0;

  for (const token of tokens) {
    for (const keyword of normalizedCategoryKeywords) {
      // Exact match
      if (token === keyword) {
        matchCount++;
      }
      // Partial match (keyword contains token or vice versa)
      else if (token.includes(keyword) || keyword.includes(token)) {
        matchCount += 0.5; // Lower score for partial matches
      }
    }
  }

  return matchCount;
}

/**
 * Main function: Suggest a category based on remark text
 *
 * @param {string} remark - The reviewer's remark text
 * @param {Array} categories - List of defect categories with keywords
 * @returns {Object} { suggestedCategoryId, categoryName, confidence, autoFill }
 */
export function suggestCategory(remark, categories) {
  // Validation
  if (!remark || typeof remark !== "string" || remark.trim().length === 0) {
    return {
      suggestedCategoryId: null,
      categoryName: null,
      confidence: 0,
      autoFill: false,
      reason: "Remark is empty or invalid",
    };
  }

  if (!categories || !Array.isArray(categories) || categories.length === 0) {
    return {
      suggestedCategoryId: null,
      categoryName: null,
      confidence: 0,
      autoFill: false,
      reason: "No categories available",
    };
  }

  // Extract tokens from remark
  const tokens = extractTokens(remark);
  if (tokens.length === 0) {
    return {
      suggestedCategoryId: null,
      categoryName: null,
      confidence: 0,
      autoFill: false,
      reason: "Could not extract meaningful tokens from remark",
    };
  }

  // Score each category
  const scores = categories.map((cat) => {
    const matchCount = countKeywordMatches(tokens, cat.keywords || []);
    const confidence = (matchCount / tokens.length) * 100;
    return {
      categoryId: cat._id || cat.id,
      categoryName: cat.name,
      matchCount,
      confidence: Math.round(confidence),
      keywords: cat.keywords || [],
    };
  });

  // Find the best match
  const bestMatch = scores.reduce((prev, current) =>
    current.confidence > prev.confidence ? current : prev
  );

  // Determine if we should auto-fill (threshold: 60%)
  const CONFIDENCE_THRESHOLD = 60;
  const autoFill = bestMatch.confidence >= CONFIDENCE_THRESHOLD;

  return {
    suggestedCategoryId: bestMatch.categoryId,
    categoryName: bestMatch.categoryName,
    confidence: bestMatch.confidence,
    autoFill,
    matchCount: bestMatch.matchCount,
    tokenCount: tokens.length,
    reason: autoFill
      ? `High confidence match (${bestMatch.confidence}%)`
      : `Low confidence match (${bestMatch.confidence}%) - suggest but don't auto-fill`,
  };
}

/**
 * Get suggestion with full scoring details (for debugging/analytics)
 */
export function suggestCategoryWithDetails(remark, categories) {
  const suggestion = suggestCategory(remark, categories);

  const tokens = extractTokens(remark);
  const detailedScores = categories.map((cat) => {
    const matchCount = countKeywordMatches(tokens, cat.keywords || []);
    return {
      categoryId: cat._id || cat.id,
      categoryName: cat.name,
      confidence: Math.round((matchCount / tokens.length) * 100),
      matchCount,
    };
  });

  return {
    ...suggestion,
    allScores: detailedScores,
    tokens,
  };
}

export default {
  suggestCategory,
  suggestCategoryWithDetails,
};
