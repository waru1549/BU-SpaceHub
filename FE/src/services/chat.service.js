import { api } from './api.js';

// คืน { session_id, answer, evidence:[{tool,args,view,sql,row_count}], model, refused }
export const askChat = async ({ message, history, sessionId }) =>
  (await api.post('/chat', { message, history, sessionId })).data;

export const getSuggestions = async () => (await api.get('/chat/suggestions')).data;
