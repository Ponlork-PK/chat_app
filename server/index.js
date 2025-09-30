const express = require('express');
const { Socket } = require('socket.io');

const app = express();
const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, ()=>{
  console.log('server running at http://localhost:3000')
} )

const io = require('socket.io')(server);

const online = new Map(); 

io.on('connection', (socket) => {
  let current = null;

  const username = socket.handshake.auth?.username || socket.id;
  online.set(username, socket.id);

  console.log('Connected:', socket.id, 'as user', username);

  socket.on('dm', (payload = {}) => {
    
    const from = String(payload.from || username);
    const to = String(payload.to || ''); 
    const text = String(payload.message ?? payload.text ?? '');
    const time = String(payload.time ?? '');

    if (!to || !text) return;  

    const out = {
      id: Date.now().toString(),
      from,
      to, 
      message: text,
      text,
      time,
      sendByMe: from,
    };
    
    const targetId = online.get(to);
    if (targetId) {
      io.to(targetId).emit('dm', out);   
    }

    socket.emit('dm', out); 
    
  });
  
  socket.on('disconnect', ()=>{
    console.log('Disconnected Successfully.', socket.id);
  });
});
