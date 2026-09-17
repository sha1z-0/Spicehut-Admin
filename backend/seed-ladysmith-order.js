import { seedOrder } from './seed-order-helper.js';

seedOrder({
  collectionName: 'ordersLadysmith',
  locationName: 'Ladysmith',
  branchName: 'Ladysmith',
  orderPrefix: 'LADYSMITH'
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error.message);
    process.exit(1);
  });
