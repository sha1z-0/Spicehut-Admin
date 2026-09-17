import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

const seedOrder = async () => {
  const now = new Date();
  const autoRejectAt = new Date(now.getTime() + 15 * 60 * 1000);

  const orderDoc = {
    orderId: 'ORDER-COMOX-SEED-001',
    orderNumber: '#COMOX-001',
    customerName: 'Seed Customer',
    customerEmail: 'seed@comox.example',
    customerPhone: '250-555-0123',
    items: [
      {
        name: 'Butter Chicken',
        description: 'Seeded item',
        price: 16.99,
        quantity: 1
      },
      {
        name: 'Naan',
        price: 3.99,
        quantity: 2
      }
    ],
    totalAmount: 24.97,
    status: 'incoming',
    location: 'Comox',
    branch: 'Comox',
    createdAt: now,
    updatedAt: now,
    autoRejectAt
  };

  await mongoose.connect(process.env.MONGO_URI);
  const collection = mongoose.connection.db.collection('ordersComox');
  const result = await collection.insertOne(orderDoc);
  console.log('✅ Seeded Comox order:', result.insertedId.toString());
  await mongoose.disconnect();
};

seedOrder().catch((error) => {
  console.error('❌ Failed to seed Comox order:', error);
  process.exit(1);
});
