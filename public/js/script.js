(function () {
  "use strict";

  // Menú móvil
  var header = document.querySelector(".site-header");
  var toggle = document.getElementById("navToggle");
  var nav = document.getElementById("nav");

  if (toggle && header && nav) {
    toggle.addEventListener("click", function () {
      var isOpen = header.classList.toggle("open");
      toggle.setAttribute("aria-expanded", String(isOpen));
    });

    nav.querySelectorAll("a").forEach(function (link) {
      link.addEventListener("click", function () {
        header.classList.remove("open");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  // Año dinámico en el footer
  var yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  // Formulario de contacto: se envía a Formspree (https://formspree.io) por
  // AJAX. Configura el endpoint real en el atributo "action" del <form> en
  // index.html (reemplaza "TU_FORM_ID" por el ID que te da Formspree).
  var form = document.getElementById("contactForm");
  var note = document.getElementById("formNote");
  var submitBtn = form ? form.querySelector("button[type=submit]") : null;

  if (form) {
    form.addEventListener("submit", function (e) {
      e.preventDefault();

      var nombre = form.nombre.value.trim();
      var correo = form.correo.value.trim();
      var mensaje = form.mensaje.value.trim();

      if (!nombre || !correo || !mensaje) {
        note.textContent = "Por favor completa nombre, correo y mensaje.";
        return;
      }

      // Para que las respuestas del correo lleguen directo al visitante.
      form.replyTo.value = correo;

      submitBtn.disabled = true;
      note.textContent = "Enviando...";

      fetch(form.action, {
        method: "POST",
        body: new FormData(form),
        headers: { Accept: "application/json" },
      })
        .then(function (response) {
          if (response.ok) {
            note.textContent = "¡Mensaje enviado! Te responderé a la brevedad.";
            form.reset();
          } else {
            return response.json().then(function (data) {
              var msg =
                data && data.errors
                  ? data.errors.map(function (er) { return er.message; }).join(", ")
                  : "Ocurrió un error al enviar el mensaje.";
              note.textContent = msg + " Escríbeme directo a " + document.getElementById("emailLink").textContent.trim() + ".";
            });
          }
        })
        .catch(function () {
          note.textContent =
            "No se pudo enviar el mensaje. Escríbeme directo a " +
            document.getElementById("emailLink").textContent.trim() + ".";
        })
        .finally(function () {
          submitBtn.disabled = false;
        });
    });
  }
})();
