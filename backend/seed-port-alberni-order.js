import { seedOrder } from './seed-order-helper.js';

seedOrder({
  collectionName: 'ordersPortAlberni',
  locationName: 'Port Alberni',
  branchName: 'Port Alberni',
  orderPrefix: 'PORTALB'
})
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error.message);
    process.exit(1);
  });
