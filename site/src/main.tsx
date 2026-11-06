import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { isLocale } from './i18n';
import './styles/site.css';

const locale = document.documentElement.lang;
const root = document.getElementById('root');
if (!isLocale(locale) || !root) throw new Error('Invalid page locale or missing root');
createRoot(root).render(
  <StrictMode>
    <App locale={locale} />
  </StrictMode>,
);
