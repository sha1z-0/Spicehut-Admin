import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

mongoose.connect(process.env.MONGO_URI)
  .then(async () => {
    console.log('✅ MongoDB Connected');
    
    const AdminUserSchema = new mongoose.Schema({
      email: { type: String, required: true, unique: true, lowercase: true },
      password: { type: String, required: true },
      name: { type: String, required: true },
      role: { type: String, enum: ['superAdmin', 'branchAdmin'], default: 'branchAdmin' },
      branch: { type: String },
      branches: [String],
      isActive: { type: Boolean, default: true },
      lastLogin: Date,
      createdAt: { type: Date, default: Date.now },
      updatedAt: { type: Date, default: Date.now }
    });

    const AdminUser = mongoose.model('AdminUser', AdminUserSchema);
    
    const admins = await AdminUser.find({});
    console.log('\n📋 Admin Users in Database:');
    console.log(JSON.stringify(admins, null, 2));
    
    process.exit(0);
  })
  .catch(err => {
    console.error('❌ MongoDB Error:', err);
    process.exit(1);
  });
