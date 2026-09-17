import { seedOrder } from './seed-order-helper.js';

seedOrder({
  collectionName: 'ordersCanmore',
  locationName: 'Canmore',
  branchName: 'Canmore',
  orderPrefix: 'CANMORE'
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error.message);
    process.exit(1);
  });
