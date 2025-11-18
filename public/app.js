// public/app.js

// Initialize Firebase App and Services (SDKs are loaded in index.html)
const auth = firebase.auth();
const db = firebase.firestore();

// Get UI Elements
const loginContainer = document.getElementById('login-container');
const adminContent = document.getElementById('admin-content');
const userEmailSpan = document.getElementById('user-email');
const errorElement = document.getElementById('error-message');
const logoutBtn = document.getElementById('logout-btn');
const googleLoginBtn = document.getElementById('google-login-btn');

// --- NEW KB Elements ---
const kbForm = document.getElementById('kb-form');
const kbQuestion = document.getElementById('kb-question');
const kbAnswer = document.getElementById('kb-answer');
const kbList = document.getElementById('kb-list');
const refreshKbBtn = document.getElementById('refresh-kb-btn');

// --- 3. Test: Load Secure Chat Logs (Verifies Rule 1B) ---
const loadLogsBtn = document.getElementById('load-logs-btn');
const logList = document.getElementById('log-list');

// --- 1. Authentication Handlers (Sign In/Out) ---
googleLoginBtn.addEventListener('click', () => {
    const provider = new firebase.auth.GoogleAuthProvider();
    auth.signInWithPopup(provider).catch(error => {
        errorElement.textContent = `Login Error: ${error.message}`;
    });
});

logoutBtn.addEventListener('click', () => {
    auth.signOut();
});

// --- 2. Authorization State Listener ---
auth.onAuthStateChanged(user => {
    if (user) {
        // User is signed in. Check if they are an ADMIN.
        userEmailSpan.textContent = user.email;
        loginContainer.style.display = 'none';
        
        // **CRITICAL AUTHORIZATION CHECK (Rule 3A):**
        // Try to read the /admins collection to verify whitelisting.
        const adminRef = db.collection('admins').doc(user.uid);
        
        adminRef.get().then((doc) => {
            if (doc.exists) {
                // SUCCESS: User is an admin. Show the secure content.
                adminContent.style.display = 'block';
                errorElement.textContent = '';
                loadKnowledgeBase(); // Load KB on successful auth
            } else {
                // FAILURE: User is authenticated but NOT an admin.
                adminContent.style.display = 'none';
                loginContainer.style.display = 'block';
                auth.signOut(); // Log out non-admin user immediately
                errorElement.textContent = "ACCESS DENIED. Your account is not whitelisted as an administrator.";
            }
        }).catch(error => {
            // This catches any rule misconfigurations or network errors.
            adminContent.style.display = 'none';
            loginContainer.style.display = 'block';
            auth.signOut();
            errorElement.textContent = "ACCESS DENIED. Could not verify admin status.";
        });

    } else {
        // User is signed out or not logged in.
        loginContainer.style.display = 'block';
    }
});

// --- 3. Chat Log Loader ---
loadLogsBtn.addEventListener('click', () => {
    logList.innerHTML = '<li>Loading...</li>';
    
    // Attempt to read the PII-sensitive chat logs (Only admins can read, Rule 1B [cite: 270])
    db.collection('chat-logs').orderBy('timestamp', 'desc').limit(5).get()
        .then(snapshot => {
            if (snapshot.empty) {
                logList.innerHTML = '<li>No chat logs found.</li>';
                return;
            }
            logList.innerHTML = ''; 
            snapshot.forEach(doc => {
                const log = doc.data();
                const listItem = document.createElement('li');
                listItem.textContent = `[${log.timestamp.toDate().toLocaleTimeString()}] Session: ${log.session_id.substring(0, 8)}...`;
                logList.appendChild(listItem);
            });
        })
        .catch(error => {
            // This error ensures no non-admin user can ever access logs.
            logList.innerHTML = `<li class="error">Error loading logs: ${error.message}. Access denied by security rules.</li>`;
        });
});

// --- 4. Knowledge Base / CMS Functions ---

// Function to load and display all documents from the 'knowledge-base' collection (Read, Rule 2A )
async function loadKnowledgeBase() {
    kbList.innerHTML = '<li>Loading entries...</li>';
    try {
        const querySnapshot = await db.collection('knowledge-base').orderBy('createdAt', 'desc').get();
        kbList.innerHTML = ''; // Clear list
        if (querySnapshot.empty) {
            kbList.innerHTML = '<li>No entries found. Click "Add New Entry" to populate the knowledge base.</li>';
            return;
        }
        querySnapshot.forEach(doc => {
            const data = doc.data();
            const li = document.createElement('li');
            li.innerHTML = `
                <div class="content">
                    <strong>Q: ${data.question}</strong>
                    <p>A: ${data.answer}</p>
                </div>
                <button class="delete-btn" data-id="${doc.id}">Delete</button>
            `;
            kbList.appendChild(li);
        });

        // Attach event listeners to all new delete buttons
        document.querySelectorAll('.delete-btn').forEach(button => {
            button.addEventListener('click', (e) => {
                const id = e.target.getAttribute('data-id');
                deleteKnowledgeItem(id);
            });
        });

    } catch (error) {
        console.error("Error loading knowledge base:", error);
        kbList.innerHTML = `<li class="error">Error: ${error.message}. Check network connection or security rules.</li>`;
    }
}

// Function to add a new document (Write, Rule 2A )
async function addKnowledgeItem(e) {
    e.preventDefault(); 
    const question = kbQuestion.value;
    const answer = kbAnswer.value;

    if (!question || !answer) {
        alert('Please fill out both the question and answer.');
        return;
    }

    try {
        await db.collection('knowledge-base').add({
            question: question,
            answer: answer,
            createdAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        
        kbForm.reset();
        loadKnowledgeBase();

    } catch (error) {
        console.error("Error adding document: ", error);
        alert("Error: " + error.message);
    }
}

// Function to delete a document (Delete, Rule 2A )
async function deleteKnowledgeItem(id) {
    if (confirm('Are you sure you want to delete this entry?')) {
        try {
            await db.collection('knowledge-base').doc(id).delete();
            loadKnowledgeBase(); 
        } catch (error) {
            console.error("Error deleting document: ", error);
            alert("Error: " + error.message);
        }
    }
}

// Attach event listeners for the new KB functions
kbForm.addEventListener('submit', addKnowledgeItem);
refreshKbBtn.addEventListener('click', loadKnowledgeBase);