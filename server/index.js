const express = require('express');
const { Socket } = require('socket.io');

const app = express();
const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, ()=>{
  console.log('server running at http://localhost:3000')
} )


const io = require('socket.io')(server);
io.on('connection', (socket) => {

  const username = socket.handshake.auth?.username || socket.id;
  console.log('Connected:', socket.id, 'as', username);

  socket.on('join', ({ room }) => {
    if (!room || typeof room !== 'string') return;
    socket.join(room);
    console.log(`Socket ${socket.id} joined room ${room}`);

    socket.emit('joined', { room });
  });

  socket.on('dm', (payload = {}) => {
    const room = String(payload.room || payload.roomId || '');
    const from = String(payload.from || username);
    const text = String(payload.message ?? payload.text ?? '');
    const time = String(payload.time ?? '');

    if (!room || !text) return;

    const out = {
      id: Date.now().toString(),
      roomId: room,
      room,
      from,
      message: text,
      text,
      time,
      sendByMe: from,
    };

    io.to(room).emit('dm', out);
  });

  socket.on('message', (data = {})=>{
    const payload = {
      id: Date.now().toString(),
      from: username,
      message: String(data.message ?? data.text ?? ''),
      text: String(data.text ?? data.message ?? '' ),
      time: new Date().toLocaleTimeString(),
      sendByMe: username,
      roomId: "global",
      room: "global",
    }
    console.log('data: ', data);
    console.log('payload: ', payload);
  });

  socket.on('disconnect', ()=>{
    console.log('Disconnected Successfully.', socket.id);
  });
});
