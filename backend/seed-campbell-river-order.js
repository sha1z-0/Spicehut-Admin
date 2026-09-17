import { seedOrder } from './seed-order-helper.js';

seedOrder({
  collectionName: 'ordersCampbellRiver',
  locationName: 'Campbell River',
  branchName: 'Campbell River',
  orderPrefix: 'CAMPBELL'
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error.message);
    process.exit(1);
  });
