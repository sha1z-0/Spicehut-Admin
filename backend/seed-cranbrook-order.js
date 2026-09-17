import { seedOrder } from './seed-order-helper.js';

seedOrder({
  collectionName: 'ordersCranbrook',
  locationName: 'Cranbrook',
  branchName: 'Cranbrook',
  orderPrefix: 'CRANBROOK'
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error.message);
    process.exit(1);
  });
