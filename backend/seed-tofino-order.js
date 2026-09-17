import { seedOrder } from './seed-order-helper.js';

seedOrder({
  collectionName: 'ordersTofino',
  locationName: 'Tofino',
  branchName: 'Tofino',
  orderPrefix: 'TOFINO'
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error.message);
    process.exit(1);
  });
