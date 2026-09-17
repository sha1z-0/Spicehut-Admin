import mongoose, { Schema, Document, Model, CallbackWithoutResultAndOptionalError } from 'mongoose';
import bcrypt from 'bcryptjs';

export interface IAdminUser extends Document {
    email: string;
    password: string;
    name: string;
    role: 'admin' | 'manager' | 'staff' | 'superAdmin' | 'branchAdmin';
    staffRole?: 'waiter' | 'cashier' | 'kitchen' | 'delivery';
    branch?: string;
    branches?: string[];
    isActive: boolean;
    lastLogin?: Date;
    createdAt: Date;
    updatedAt: Date;
    comparePassword(candidatePassword: string): Promise<boolean>;
}

const AdminUserSchema = new Schema<IAdminUser>(
    {
        email: {
            type: String,
            required: true,
            unique: true,
            lowercase: true,
            trim: true,
            match: /.+\@.+\..+/,
        },
        password: {
            type: String,
            required: true,
            minlength: 6,
        },
        name: {
            type: String,
            required: true,
        },
        role: {
            type: String,
            enum: ['admin', 'manager', 'staff', 'superAdmin', 'branchAdmin'],
            default: 'manager',
        },
        staffRole: {
            type: String,
            enum: ['waiter', 'cashier', 'kitchen', 'delivery'],
        },
        branch: {
            type: String,
        },
        branches: {
            type: [String],
            default: [],
        },
        isActive: {
            type: Boolean,
            default: true,
        },
        lastLogin: {
            type: Date,
        },
    },
    { timestamps: true }
);

// Hash password before saving
AdminUserSchema.pre<IAdminUser>('save', async function (next: CallbackWithoutResultAndOptionalError) {
    if (!this.isModified('password')) {
        next();
        return;
    }

    try {
        const salt = await bcrypt.genSalt(10);
        this.password = await bcrypt.hash(this.password, salt);
        next();
    } catch (error) {
        next(error as Error);
    }
});

// Method to compare passwords
AdminUserSchema.methods.comparePassword = async function (
    candidatePassword: string
): Promise<boolean> {
    try {
        return await bcrypt.compare(candidatePassword, this.password);
    } catch (error) {
        throw error;
    }
};

// Index for email lookups
AdminUserSchema.index({ email: 1 });
AdminUserSchema.index({ branch: 1 });
AdminUserSchema.index({ role: 1 });

export default mongoose.models.AdminUser ||
    mongoose.model<IAdminUser>('AdminUser', AdminUserSchema);
