const express = require('express');
const { Socket } = require('socket.io');

const app = express();
const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, ()=>{
  console.log('server running at http://10.10.77.191:3000')
} )

const io = require('socket.io')(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
  maxHttpBufferSize: 50 * 1024 * 1024,
});

const online = new Map(); 

io.on('connection', (socket) => {

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

  socket.on('media', (payload = {}, ask) => {
    try {
      const from = String(payload.from || username);
      const to = String(payload.to || '');
      const type = String(payload.type || 'image');
      const name = String(payload.name || '');
      const mime = String(payload.mime || '');
      const time = String(payload.time ?? '');
      const data = payload.data;

      if(!to && !data) {
        ask?.({ok: false, error: 'Missing "to" or "data".'});
        return
      };

      var out = {
        id: Date.now().toString(),
        from,
        to,
        type,
        name,
        mime,
        data,
        time,
      };

      const targetId = online.get(to);
      const delivered = !!targetId;

      if(targetId) io.to(targetId).emit('media', out);

      socket.emit('media', out);
      
      ask?.({ok: true, delivered});
    } catch(e) {
      console.error('media error:', e);
      ask?.({ ok: false, error: 'media failed'});
    };
  });

  socket.on('audio', (payload = {}, ask) => {
    try {
      const from = String(payload.from || username);
      const to = String(payload.to || '');
      const type = String(payload.type || 'audio');
      const name = String(payload.name || 'voice.m4a');
      const mime = String(payload.mime || 'audio/mp4');
      const time = String(payload.time ?? '');
      const duration = Number(payload.duration ?? 0) || 0;
      const wave = Array.isArray(payload.wave) ? payload.wave : [];
      const data = payload.data;

      if(!to && !data) {
        ask?.({ok: false, error: 'Missing "to" or "data".'});
        return
      };

      var out = {
        id: Date.now().toString(),
        from,
        to,
        type,
        name,
        mime,
        duration,
        wave,
        data,
        time,
      };

      const targetId = online.get(to);
      const delivered = !!targetId;

      if(targetId) io.to(targetId).emit('audio', out);

      socket.emit('audio', out);
      
      ask?.({ok: true, delivered});
    } catch(e) {
      console.error('audio error:', e);
      ask?.({ ok: false, error: 'audio failed'});
    };
  });
  
  socket.on('disconnect', ()=>{
    console.log('Disconnected Successfully.', socket.id);
  });
});
