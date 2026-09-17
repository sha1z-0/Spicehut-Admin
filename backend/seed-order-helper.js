import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

const buildEmailDomain = (locationName) => {
  if (!locationName) return 'location';
  return locationName.toLowerCase().replace(/[^a-z0-9]+/g, '') || 'location';
};

export async function seedOrder({
  collectionName,
  locationName,
  branchName,
  orderPrefix
}) {
  if (!process.env.MONGO_URI) {
    throw new Error('MONGO_URI is not set');
  }
  if (!collectionName || !locationName || !orderPrefix) {
    throw new Error('Missing required seed order parameters');
  }

  const now = new Date();
  const emailDomain = buildEmailDomain(locationName);
  const testOrder = {
    orderId: `TEST-${orderPrefix}-${Date.now()}`,
    orderNumber: `#${orderPrefix}${Math.floor(Math.random() * 9999)}`,
    customerName: `Test Customer ${locationName}`,
    customerPhone: '250-555-1234',
    customerEmail: `test@${emailDomain}.com`,
    status: 'incoming',
    items: [
      { name: 'Butter Chicken', quantity: 2, price: 16.99 },
      { name: 'Garlic Naan', quantity: 1, price: 3.99 },
      { name: 'Mango Lassi', quantity: 2, price: 4.99 }
    ],
    totalAmount: 49.95,
    orderTotal: 49.95,
    location: locationName,
    branch: branchName || locationName,
    type: 'online',
    paymentMethod: 'card',
    specialInstructions: 'Test order inserted directly to DB',
    createdAt: now,
    updatedAt: now,
    autoRejectAt: new Date(now.getTime() + 15 * 60 * 1000)
  };

  await mongoose.connect(process.env.MONGO_URI);
  const db = mongoose.connection.db;

  console.log(`\nInserting test order into ${collectionName} collection...\n`);
  const result = await db.collection(collectionName).insertOne(testOrder);

  console.log('Order inserted successfully.');
  console.log('  _id:', result.insertedId);
  console.log('  orderNumber:', testOrder.orderNumber);
  console.log('  customerName:', testOrder.customerName);
  console.log('  totalAmount:', testOrder.totalAmount);
  console.log('  status:', testOrder.status);
  console.log(`\nCheck backend logs for change stream: orders${locationName.replace(/\s+/g, '')}`);
  console.log('Watch the incoming orders screen for the notification.\n');

  await mongoose.disconnect();
}