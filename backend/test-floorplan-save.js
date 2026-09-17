import fetch from 'node-fetch';

// Test credentials - use superadmin
const testLogin = {
  email: 'superadmin@spicehut.com',
  password: 'SuperAdmin@123'
};

const testFloorPlan = {
  branchId: 'Canmore',
  sections: [
    {
      id: 'main_hall',
      name: 'Main Hall',
      type: 'standard',
      tables: [
        {
          id: '1',
          name: '1',
          seats: 4,
          x: 100,
          y: 100,
          rotation: 0,
          isOccupied: false
        }
      ]
    }
  ]
};

async function test() {
  try {
    // 1. Login
    console.log('📧 Logging in...');
    const loginRes = await fetch('http://localhost:4000/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(testLogin)
    });
    
    const loginData = await loginRes.json();
    console.log('✅ Login response:', loginData.success ? 'Success' : 'Failed');
    console.log('👤 Role:', loginData.admin?.role);
    console.log('🌿 Branch:', loginData.admin?.branch || 'null');
    console.log('🌳 Branches:', loginData.admin?.branches?.join(', ') || 'none');
    
    if (!loginData.success) {
      console.error('❌ Login failed');
      return;
    }
    
    const token = loginData.token;
    
    // 2. Save floor plan
    console.log('\n💾 Saving floor plan...');
    const saveRes = await fetch('http://localhost:4000/api/tables/floorplan', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(testFloorPlan)
    });
    
    const saveData = await saveRes.json();
    console.log('📊 Save response status:', saveRes.status);
    console.log('📦 Save response:', JSON.stringify(saveData, null, 2));
    
    if (saveData.success) {
      console.log('✅ Floor plan saved successfully!');
    } else {
      console.log('❌ Save failed:', saveData.message);
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

test();
