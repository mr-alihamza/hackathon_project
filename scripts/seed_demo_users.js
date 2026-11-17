
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({
    credential: applicationDefault(),
});

const auth = getAuth();
const db = getFirestore();

const password = 'Demo123!';

const demoUsers = [
    {
        code: 'ADMIN',
        name: 'Admin',
        email: 'admin@novaworks.example',
        role: 'ADMIN',
        specialization: 'Company Administration',
        skills: ['Company overview', 'Transcript creation'],
    },
    {
        code: 'PM01',
        name: 'Ayesha Khan',
        email: 'ayesha@novaworks.example',
        role: 'MANAGER',
        specialization: 'Web PM',
        skills: ['Web projects', 'Client coordination'],
    },
    {
        code: 'PM02',
        name: 'Bilal Ahmed',
        email: 'bilal@novaworks.example',
        role: 'MANAGER',
        specialization: 'Mobile PM',
        skills: ['Mobile projects', 'Delivery planning'],
    },
    {
        code: 'PM03',
        name: 'Hina Malik',
        email: 'hina@novaworks.example',
        role: 'MANAGER',
        specialization: 'AI PM',
        skills: ['AI projects', 'Requirement review'],
    },
    {
        code: 'DEV01',
        name: 'Ali Raza',
        email: 'ali@novaworks.example',
        role: 'AGENT',
        specialization: 'Full-Stack Developer',
        skills: ['React', 'Frontend integration'],
    },
    {
        code: 'DEV02',
        name: 'Hamza Shah',
        email: 'hamza@novaworks.example',
        role: 'AGENT',
        specialization: 'Full-Stack Developer',
        skills: ['Node.js', 'Databases', 'APIs'],
    },
    {
        code: 'DEV03',
        name: 'Sara Noor',
        email: 'sara@novaworks.example',
        role: 'AGENT',
        specialization: 'App Developer',
        skills: ['Flutter', 'Mobile UI'],
    },
    {
        code: 'DEV04',
        name: 'Usman Tariq',
        email: 'usman@novaworks.example',
        role: 'AGENT',
        specialization: 'App Developer',
        skills: ['Flutter', 'Integration', 'Testing'],
    },
    {
        code: 'DEV05',
        name: 'Zain Abbas',
        email: 'zain@novaworks.example',
        role: 'AGENT',
        specialization: 'AI Developer',
        skills: ['LLMs', 'Extraction', 'Prompts'],
    },
    {
        code: 'DEV06',
        name: 'Maryam Asif',
        email: 'maryam@novaworks.example',
        role: 'AGENT',
        specialization: 'AI Developer',
        skills: ['Retrieval', 'Document processing'],
    },
];

async function seedDemoUsers() {
    console.log('Starting NovaWorks demo account setup...');

    for (const employee of demoUsers) {
        try {
            let user;

            try {
                user = await auth.getUserByEmail(employee.email);

                user = await auth.updateUser(user.uid, {
                    password,
                    displayName: employee.name,
                    disabled: false,
                });
            } catch (error) {
                if (error.code !== 'auth/user-not-found') {
                    throw error;
                }

                user = await auth.createUser({
                    email: employee.email,
                    password,
                    displayName: employee.name,
                    disabled: false,
                });
            }

            await db.collection('users').doc(user.uid).set({
                employeeCode: employee.code,
                name: employee.name,
                email: employee.email,
                role: employee.role,
                specialization: employee.specialization,
                skills: employee.skills,
            });

            console.log(`Created/updated: ${employee.email}`);
        } catch (error) {
            console.error(`Failed: ${employee.email}`, error.message);
            throw error;
        }
    }

    console.log('All ten demo accounts are ready.');
}

seedDemoUsers()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error('Seeding failed:', error);
        process.exit(1);
    });
