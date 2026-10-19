// Message bref (Toast), disparaît après 2,6 s.

class Toast {
  message = $state('');
  #minuteur = 0;

  afficher(message) {
    this.message = message;
    clearTimeout(this.#minuteur);
    this.#minuteur = setTimeout(() => (this.message = ''), 2600);
  }

  masquer() {
    clearTimeout(this.#minuteur);
    this.message = '';
  }
}

export const toast = new Toast();
