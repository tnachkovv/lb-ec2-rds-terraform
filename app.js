const http = require('http');
const url = require('url');
const mysql = require('mysql');
const fs = require('fs');

// MySQL database configuration
const dbConfig = {
  host: 'your_database_host',
  user: 'your_username',
  password: 'your_password',
  database: 'your_database_name'
};

const connection = mysql.createConnection(dbConfig);

// Create a simple HTTP server
const server = http.createServer((req, res) => {
  const reqUrl = url.parse(req.url, true);

  // Serve the homepage
  if (reqUrl.pathname === '/') {
    fs.readFile('index.html', 'utf8', (err, data) => {
      if (err) {
        res.writeHead(500);
        res.end('Error loading index.html');
      } else {
        res.writeHead(200, {'Content-Type': 'text/html'});
        res.end(data);
      }
    });
  }

  // Handle button click and MySQL query
  if (reqUrl.pathname === '/sendRequest') {
    // Insert a record into the database
    const sqlQuery = 'INSERT INTO messages (message) VALUES (?)';
    const message = 'Button clicked at ' + new Date();

    connection.query(sqlQuery, [message], (error, results) => {
      if (error) {
        res.writeHead(500);
        res.end('Error inserting into the database');
      } else {
        res.writeHead(200, {'Content-Type': 'text/plain'});
        res.end('Request sent and recorded in the database');
      }
    });
  }
});

// Start the server on port 3000
server.listen(3000, () => {
  console.log('Server running on http://localhost:3000');
});


