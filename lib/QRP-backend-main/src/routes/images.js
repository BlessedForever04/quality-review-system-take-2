import express from 'express';
const router = express.Router();
import multer from 'multer';
const upload = multer();
import { init, uploadImage, getImagesByQuestion, getImagesByQuestionAndRole, downloadImageById, deleteImageById } from '../gridfs.js';

// Initialize GridFS using environment variables (same as main DB connection)
const MONGO_URI = `${process.env.MONGO_DB_URI}/${process.env.DB_NAME}`;
const DB_NAME = process.env.DB_NAME;
init(MONGO_URI, DB_NAME).catch(err => {
    console.error('Failed to init GridFS', err);
});

// Upload image for a questionId with role (executor or reviewer)
// POST /images/:questionId?role=executor or /images/:questionId?role=reviewer
router.post('/images/:questionId', upload.single('image'), async (req, res) => {
    try {
        const { questionId } = req.params;
        const { role } = req.query; // Get role from query parameter
        if (!req.file || !req.file.buffer) {
            return res.status(400).json({ error: 'No image file provided' });
        }
        if (role && !['executor', 'reviewer'].includes(role)) {
            return res.status(400).json({ error: 'Invalid role. Must be executor or reviewer' });
        }
        const file = await uploadImage(
            questionId,
            req.file.buffer,
            req.file.originalname || 'upload.jpg',
            req.file.mimetype || 'image/jpeg',
            role // Pass role to store in metadata
        );
        return res.status(201).json({ fileId: file?.id, filename: file?.filename });
    } catch (e) {
        console.error(e);
        return res.status(500).json({ error: e.message });
    }
});

// List images by questionId and optionally by role
// GET /images/:questionId?role=executor or /images/:questionId?role=reviewer
router.get('/images/:questionId', async (req, res) => {
    try {
        const { questionId } = req.params;
        const { role } = req.query;
        
        let files;
        if (role && ['executor', 'reviewer'].includes(role)) {
            files = await getImagesByQuestionAndRole(questionId, role);
        } else {
            files = await getImagesByQuestion(questionId);
        }
        
        return res.json(files.map(f => ({
            _id: f._id,
            filename: f.filename,
            length: f.length,
            uploadDate: f.uploadDate,
            contentType: f.contentType,
            role: f.metadata?.role, // Include role in response
        })));
    } catch (e) {
        console.error(e);
        return res.status(500).json({ error: e.message });
    }
});

// Download by file id
router.get('/images/file/:fileId', async (req, res) => {
    try {
        // Find file doc to set correct headers
        const files = await getImagesByQuestion('__dummy__'); // placeholder to access db via bucket
        // Use bucket's db to query fs.files collection directly
        const { ObjectId } = await import('mongodb');
        const id = new ObjectId(req.params.fileId);
        const fileDoc = await (globalThis._uploadsDb || null)?.collection('uploads.files').findOne({ _id: id });
        // Fallback: try via bucket.find
        let contentType = 'application/octet-stream';
        if (!fileDoc) {
            try {
                const bucketFiles = await downloadImageById(req.params.fileId); // will throw if not found
            } catch (_) { }
        } else {
            contentType = fileDoc.metadata?.contentType || fileDoc.contentType || contentType;
        }
        res.setHeader('Content-Type', contentType);
        const stream = await downloadImageById(req.params.fileId);
        stream.on('error', err => {
            console.error(err);
            res.status(404).json({ error: 'File not found' });
        });
        stream.pipe(res);
    } catch (e) {
        console.error(e);
        return res.status(500).json({ error: e.message });
    }
});

// Delete by file id
router.delete('/images/file/:fileId', async (req, res) => {
    try {
        const { fileId } = req.params;
        await deleteImageById(fileId);
        return res.status(204).end();
    } catch (e) {
        console.error(e);
        // If not found, Mongo throws, respond 404
        if (String(e?.message || '').toLowerCase().includes('not found')) {
            return res.status(404).json({ error: 'File not found' });
        }
        return res.status(500).json({ error: e.message });
    }
});

export default router;
