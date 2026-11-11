// ESLint for the dotfiles repository. herdr-app mods are Herdr's own code, cloned with a few strings
// changed, so linting them would judge Herdr's style; they stay out.
export default [
  { ignores: ["herdr-app/**/mods/**"] },
];
