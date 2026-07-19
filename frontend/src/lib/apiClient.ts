import axios from 'axios';

// Nullish coalescing (??), NOT ||, so an explicitly empty string ("")
// is respected — that's what makes requests relative to the current
// origin (CloudFront domain) in production, avoiding any hardcoded domain.
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8080';

export const apiClient = axios.create({
    baseURL: API_BASE_URL,
    withCredentials: true, // Crucial for httpOnly cookies
});