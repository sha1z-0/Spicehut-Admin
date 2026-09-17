import { seedOrder } from './seed-order-helper.js';

seedOrder({
  collectionName: 'ordersComox',
  locationName: 'Comox',
  branchName: 'Comox',
  orderPrefix: 'COMOX'
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error.message);
    process.exit(1);
  });
