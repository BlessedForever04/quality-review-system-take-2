const BASE_URL = 'http://localhost:8000/api/v1';

async function test() {
  try {
    console.log('\n🧪 Starting Persistence Test...\n');
    
    // First, create a template
    console.log('1️⃣ Creating template...');
    const createRes = await fetch(`${BASE_URL}/templates`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Test Template',
        projectId: 'test-project-id',
        description: 'Testing dynamic stage persistence'
      })
    });
    const createData = await createRes.json();
    const templateId = createData.data._id;
    console.log(`✅ Template created: ${templateId}`);
    console.log(`   Initial stages in response: ${JSON.stringify(createData.data)}\n`);
    
    // Add a stage via API
    console.log('2️⃣ Adding stage via API...');
    const stageRes = await fetch(`${BASE_URL}/templates/stages`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        stage: 'stage1',
        stageName: 'Test Phase'
      })
    });
    const stageData = await stageRes.json();
    console.log(`✅ API response: ${stageRes.status}`);
    console.log(`   Response data has stage1: ${'stage1' in stageData.data}`);
    console.log(`   Response: ${JSON.stringify(stageData.data, null, 2)}\n`);
    
    // Now fetch the template
    console.log('3️⃣ Fetching template...');
    const getRes = await fetch(`${BASE_URL}/templates`);
    const getData = await getRes.json();
    const template = getData.data;
    console.log(`✅ Fetched template`);
    console.log(`   Has stage1 in response: ${'stage1' in template}`);
    console.log(`   Template keys: ${Object.keys(template).join(', ')}`);
    console.log(`   Full template: ${JSON.stringify(template, null, 2)}\n`);
    
    // Check if stage1 exists
    if ('stage1' in template) {
      console.log('✅ SUCCESS: stage1 was persisted and retrieved!');
      console.log(`   stage1 value: ${JSON.stringify(template.stage1)}`);
      console.log(`   stageNames: ${JSON.stringify(template.stageNames)}`);
    } else {
      console.log('❌ FAILURE: stage1 was NOT persisted or retrieved!');
      console.log(`   Available fields: ${Object.keys(template).join(', ')}`);
    }
    
  } catch (error) {
    console.error('\n❌ Error during test:');
    console.error(error.message);
  }
}

test();
