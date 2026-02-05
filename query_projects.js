// Simple Node.js script to query MongoDB
const { MongoClient } = require('mongodb');

const uri = process.env.MONGODB_URI || "mongodb+srv://rakshikha:rakshikha@cluster0.7uib7le.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0";
const client = new MongoClient(uri);

async function main() {
    try {
        await client.connect();
        const db = client.db('test');
        
        // Get projects
        const projects = await db.collection('projects').find({}).limit(5).toArray();
        console.log('\n=== Projects ===');
        projects.forEach(p => {
            console.log(`ID: ${p._id}, Name: ${p.project_name}, Status: ${p.status}`);
        });
        
        // Get memberships
        const memberships = await db.collection('projectmemberships').find({}).limit(10).toArray();
        console.log('\n=== Project Memberships ===');
        memberships.forEach(m => {
            console.log(`Project: ${m.project_id}, User: ${m.user_id}, Role: ${m.role}`);
        });
        
    } finally {
        await client.close();
    }
}

main().catch(console.error);
