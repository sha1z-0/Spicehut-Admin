import mongoose from 'mongoose';
import dotenv from 'dotenv';
import { Server as SocketIOServer } from 'socket.io';
import http from 'http';

dotenv.config();

const simulateNewOrder = async () => {
  const now = new Date();
  const autoRejectAt = new Date(now.getTime() + 15 * 60 * 1000);
  
  // Generate unique order ID and number based on timestamp
  const timestamp = Date.now();
  const orderId = `TEST-${timestamp}`;
  const orderNumber = `TEST-${timestamp.toString().slice(-8)}`;

  const orderDoc = {
    orderId: orderId,
    orderNumber: orderNumber,
    customerName: 'Test Customer',
    customerEmail: 'test@customer.com',
    customerPhone: '250-555-9999',
    items: [
      {
        name: 'Chicken Tikka Masala',
        description: 'Test order to verify notification system',
        price: 18.99,
        quantity: 1
      },
      {
        name: 'Garlic Naan',
        price: 4.99,
        quantity: 2
      },
      {
        name: 'Mango Lassi',
        price: 5.99,
        quantity: 1
      }
    ],
    totalAmount: 34.96,
    status: 'incoming',
    location: 'Comox',
    branch: 'Comox',
    createdAt: now,
    updatedAt: now,
    autoRejectAt
  };

  try {
    console.log('🔄 Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ Connected to MongoDB');
    
    const collection = mongoose.connection.db.collection('ordersComox');
    const result = await collection.insertOne(orderDoc);
    
    console.log('\n✅ Test order inserted successfully!');
    console.log('📋 Order Details:');
    console.log(`   Order ID: ${orderId}`);
    console.log(`   Order Number: ${orderNumber}`);
    console.log(`   Customer: ${orderDoc.customerName}`);
    console.log(`   Total: $${orderDoc.totalAmount}`);
    console.log(`   Status: ${orderDoc.status}`);
    console.log(`   Location: ${orderDoc.location}`);
    console.log(`   MongoDB _id: ${result.insertedId.toString()}`);
    console.log('\n🔔 Notification should be triggered if:');
    console.log('   1. Admin app is running and logged in');
    console.log('   2. Location is set to "Comox"');
    console.log('   3. WebSocket connection is active');
    console.log('\n💡 Check the admin app for:');
    console.log('   - Ringtone sound playing');
    console.log('   - Orange notification banner (if not on incoming orders screen)');
    console.log('   - New order appearing in incoming orders list');
    
    await mongoose.disconnect();
    console.log('\n✅ Disconnected from MongoDB');
  } catch (error) {
    console.error('❌ Failed to insert test order:', error);
    process.exit(1);
  }
};

simulateNewOrder();
