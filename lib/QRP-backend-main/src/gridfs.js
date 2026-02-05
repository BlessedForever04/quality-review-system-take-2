import { MongoClient, GridFSBucket, ObjectId } from "mongodb";

let client;
let db;
let bucket;

async function init(uri, dbName) {
  if (bucket) return bucket;
  client = await MongoClient.connect(uri);
  db = client.db(dbName);
  bucket = new GridFSBucket(db, { bucketName: "uploads" });
  return bucket;
}

async function uploadImage(
  questionId,
  buffer,
  filename,
  contentType,
  role = null,
) {
  if (!bucket) throw new Error("GridFS not initialized");
  return new Promise((resolve, reject) => {
    const metadata = { questionId, contentType };
    if (role) metadata.role = role; // Store role (executor or reviewer)
    const uploadStream = bucket.openUploadStream(filename, { metadata });
    uploadStream.on("error", (err) => reject(err));
    uploadStream.on("finish", () => {
      // Use uploadStream.id provided by the driver - convert to string
      resolve({ id: uploadStream.id.toString(), filename });
    });
    uploadStream.end(buffer);
  });
}

async function getImagesByQuestion(questionId) {
  if (!bucket) throw new Error("GridFS not initialized");
  const cursor = bucket.find({ "metadata.questionId": questionId });
  return cursor.toArray();
}

async function getImagesByQuestionAndRole(questionId, role) {
  if (!bucket) throw new Error("GridFS not initialized");
  // Query for images with the specific role OR with no role (backward compatibility - treat as executor)
  const query =
    role === "executor"
      ? {
          "metadata.questionId": questionId,
          $or: [
            { "metadata.role": "executor" },
            { "metadata.role": { $exists: false } }, // Old images without role are treated as executor images
          ],
        }
      : {
          "metadata.questionId": questionId,
          "metadata.role": role,
        };
  const cursor = bucket.find(query);
  return cursor.toArray();
}

async function downloadImageById(fileId) {
  if (!bucket) throw new Error("GridFS not initialized");
  return bucket.openDownloadStream(new ObjectId(fileId));
}
async function deleteImageById(fileId) {
  if (!bucket) throw new Error("GridFS not initialized");
  return bucket.delete(new ObjectId(fileId));
}

async function deleteImagesByFileIds(fileIds) {
  if (!bucket) throw new Error("GridFS not initialized");
  const deletePromises = fileIds.map((fileId) => {
    try {
      return bucket.delete(new ObjectId(fileId));
    } catch (err) {
      console.error(`Failed to delete image ${fileId}:`, err);
      return null;
    }
  });
  return Promise.allSettled(deletePromises);
}

async function getFileMetadata(fileId) {
  if (!db) throw new Error("GridFS not initialized");
  return db.collection("uploads.files").findOne({ _id: new ObjectId(fileId) });
}

export {
  init,
  uploadImage,
  getImagesByQuestion,
  getImagesByQuestionAndRole,
  downloadImageById,
  deleteImageById,
  deleteImagesByFileIds,
  getFileMetadata,
};
