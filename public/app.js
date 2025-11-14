// public/app.js

// Initialize Firebase App and Services (SDKs are loaded in index.html)
const auth = firebase.auth();
const db = firebase.firestore();

const loginContainer = document.getElementById('login-container');
const adminContent = document.getElementById('admin-content');
const userEmailSpan = document.getElementById('user-email');
const errorElement = document.getElementById('error-message');

// --- 1. Authentication Handlers (Sign In/Out) ---

document.getElementById('google-login-btn').addEventListener('click', () => {
    const provider = new firebase.auth.GoogleAuthProvider();
    // Prompt the user to log in via Google
    auth.signInWithPopup(provider).catch(error => {
        errorElement.textContent = `Login Error: ${error.message}`;
    });
});

document.getElementById('logout-btn').addEventListener('click', () => {
    // Standard Firebase sign out
    auth.signOut();
});

// --- 2. Authorization State Listener ---

// This function runs every time the user's login state changes (login, logout, token refresh)
auth.onAuthStateChanged(user => {
    if (user) {
        // User is signed in. We now need to check if they are whitelisted as an ADMIN.
        
        userEmailSpan.textContent = user.email;
        loginContainer.style.display = 'none';
        
        // **CRITICAL AUTHORIZATION CHECK (Implicit Firestore Rule Validation):**
        // We attempt a simple database read of the /admins collection using the user's UID.
        // If the user's UID is NOT in /admins, the Firestore Rule 3A denies the read, 
        // triggering the .catch block below. This is how we enforce the whitelist.
        const adminRef = db.collection('admins').doc(user.uid);
        
        adminRef.get().then((doc) => {
            if (doc.exists) {
                // SUCCESS: User is an admin. Show the secure content.
                adminContent.style.display = 'block';
                errorElement.textContent = '';
                console.log("Authorization Successful: User is in the /admins collection.");
            } else {
                // FAILURE: User is authenticated but NOT an admin.
                adminContent.style.display = 'none';
                loginContainer.style.display = 'block';
                auth.signOut(); // Log out non-admin user immediately
                errorElement.textContent = "ACCESS DENIED. Your account is not whitelisted as an administrator.";
                console.warn("Access Denied: User " + user.email + " is not in the /admins collection.");
            }
        }).catch(error => {
            // This can happen if rules are misconfigured, but generally catches permission-denied.
            adminContent.style.display = 'none';
            loginContainer.style.display = 'block';
            auth.signOut();
            errorElement.textContent = "ACCESS DENIED. Could not verify admin status.";
            console.error("Authorization check failed:", error.message);
        });

    } else {
        // User is signed out or not logged in.
        loginContainer.style.display = 'block';
        adminContent.style.display = 'none';
        errorElement.textContent = '';
    }
});


// --- 3. Test: Load Secure Chat Logs (Verifies Rule 1B) ---

document.getElementById('load-logs-btn').addEventListener('click', () => {
    const logList = document.getElementById('log-list');
    logList.innerHTML = 'Loading...';
    
    // Attempt to read the PII-sensitive chat logs
    db.collection('chat-logs').orderBy('timestamp', 'desc').limit(5).get()
        .then(snapshot => {
            logList.innerHTML = ''; // Clear "Loading..."
            if (snapshot.empty) {
                logList.innerHTML = '<li>No chat logs found.</li>';
                return;
            }
            snapshot.forEach(doc => {
                const log = doc.data();
                const listItem = document.createElement('li');
                // Displaying a small part of the session ID for demonstration
                listItem.textContent = `[${log.timestamp.toDate().toLocaleTimeString()}] Session: ${log.session_id.substring(0, 8)}...`;
                logList.appendChild(listItem);
            });
        })
        .catch(error => {
            // This will fail if the user is not an admin, as defined in Rule 1B.
            logList.innerHTML = `<li style="color:red;">Error: ${error.message}</li>`;
            console.error("Chat Log Read Failed:", error);
        });
});