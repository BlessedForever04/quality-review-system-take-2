import express from "express"
import cookieParser from "cookie-parser"
import cors from "cors"
const app=express()


app.use(cors({
    origin:true,
    credentials:true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"]
})
)

app.use(express.json({limit: "16kb"}))
app.use(express.urlencoded({extended:true,limit:"16kb"}))



app.use(cookieParser())

//routes
import userRouter from "./routes/user.routes.js"
import roleRoutes from './routes/role.routes.js';
import projectMembershipRoutes from './routes/projectMembership.routes.js';
import projectRoutes from './routes/project.routes.js';
import checklistRoutes from './routes/checklistRoutes.js';
import checklistAnswerRoutes from './routes/checklistAnswerRoutes.js';
import stageRouter from "./routes/stage.routes.js"
import approvalRoutes from './routes/approval.routes.js';
// New routes for template and checkpoint features (integrated from V3)
import templateRoutes from './routes/template.routes.js';
import checkpointRoutes from './routes/checkpoint.routes.js';

//routes declaration
app.use("/api/v1/users",userRouter)
app.use('/api/v1/roles', roleRoutes);
// Mount membership routes BEFORE project routes to avoid ":id" catching "members"
app.use('/api/v1/projects', projectMembershipRoutes);
app.use('/api/v1/projects', projectRoutes);
app.use('/api/v1/checklists', checklistRoutes);
app.use('/api/v1', checklistAnswerRoutes);
app.use("/api/v1",stageRouter)
app.use('/api/v1', approvalRoutes);
// Template and checkpoint routes (integrated from V3)
app.use('/api/v1/templates', templateRoutes);
app.use('/api/v1', checkpointRoutes);


export {app}