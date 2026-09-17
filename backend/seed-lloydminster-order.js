import { seedOrder } from './seed-order-helper.js';

seedOrder({
  collectionName: 'ordersLloydminster',
  locationName: 'Lloydminster',
  branchName: 'Lloydminster',
  orderPrefix: 'LLOYD'
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error.message);
    process.exit(1);
  });
