import mongoose from "mongoose";
import { seedRoles } from "../utils/seedRoles.js";
import { fixRoleIndexes } from "../utils/fixRoleIndexes.js";
import dotenv from "dotenv";
dotenv.config({
    path:'./.env'
})
const connectDB=async ()=>{
    try{
        

        const connectionInstance=await mongoose.connect(`${process.env.MONGO_DB_URI}/${process.env.DB_NAME}`)
        console.log(`\n MongoDB connected!! DB HOST: ${connectionInstance.connection.host}`);
        
        // One-time fix: clean up old SDH roles and rebuild with TeamLeader
        // Comment this out after first successful run
        await fixRoleIndexes();
    }
    catch(error){
        console.log("MONGODB CONNECTION ERROR" , error);
        process.exit(1)
    }
}

export default connectDB