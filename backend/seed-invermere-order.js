import { seedOrder } from './seed-order-helper.js';

seedOrder({
  collectionName: 'ordersInvermere',
  locationName: 'Invermere',
  branchName: 'Invermere',
  orderPrefix: 'INVERMERE'
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error.message);
    process.exit(1);
  });
