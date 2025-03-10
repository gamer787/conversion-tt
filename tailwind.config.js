/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        cyan: {
          400: '#00E5FF',
          300: '#33EEFF',
        }
      }
    },
  },
  plugins: [],
};