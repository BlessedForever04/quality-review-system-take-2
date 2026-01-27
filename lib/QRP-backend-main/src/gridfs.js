import { MongoClient, GridFSBucket, ObjectId } from 'mongodb';

let client;
let db;
let bucket;

async function init(uri, dbName) {
    if (bucket) return bucket;
    client = await MongoClient.connect(uri, { useUnifiedTopology: true });
    db = client.db(dbName);
    bucket = new GridFSBucket(db, { bucketName: 'uploads' });
    return bucket;
}

async function uploadImage(questionId, buffer, filename, contentType) {
    if (!bucket) throw new Error('GridFS not initialized');
    return new Promise((resolve, reject) => {
        const uploadStream = bucket.openUploadStream(filename, {
            metadata: { questionId, contentType }
        });
        uploadStream.on('error', (err) => reject(err));
        uploadStream.on('finish', () => {
            // Use uploadStream.id provided by the driver
            resolve({ id: uploadStream.id, filename });
        });
        uploadStream.end(buffer);
    });
}

async function getImagesByQuestion(questionId) {
    if (!bucket) throw new Error('GridFS not initialized');
    const cursor = bucket.find({ 'metadata.questionId': questionId });
    return cursor.toArray();
}

async function downloadImageById(fileId) {
    if (!bucket) throw new Error('GridFS not initialized');
    return bucket.openDownloadStream(new ObjectId(fileId));
}
async function deleteImageById(fileId) {
    if (!bucket) throw new Error('GridFS not initialized');
    return bucket.delete(new ObjectId(fileId));
}

export { init, uploadImage, getImagesByQuestion, downloadImageById, deleteImageById };
