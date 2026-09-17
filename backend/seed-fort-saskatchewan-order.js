import { seedOrder } from './seed-order-helper.js';

seedOrder({
  collectionName: 'ordersNanaimo',
  locationName: 'Fort Saskatchewan',
  branchName: 'Fort Saskatchewan',
  orderPrefix: 'FORTSASK'
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error.message);
    process.exit(1);
  });
