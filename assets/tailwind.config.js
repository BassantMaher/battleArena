/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/tap_game_web.ex',
    '../lib/tap_game_web/**/*.*ex'
  ],
  theme: {
    extend: {
      colors: {
        brand: '#FD4F00',
      },
      animation: {
        gradient: 'gradient 3s ease infinite',
      },
      keyframes: {
        gradient: {
          '0%, 100%': {
            'background-position': '0% 50%',
          },
          '50%': {
            'background-position': '100% 50%',
          },
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    // Phoenix UI components use daisyUI
    // require('daisyui'),
  ],
}
