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

  // Formulario de contacto: sin backend propio, abre el cliente de correo
  // con los datos precargados. Sustituye este bloque por una integración
  // real (API propia, Formspree, etc.) cuando tengas backend disponible.
  var form = document.getElementById("contactForm");
  var note = document.getElementById("formNote");
  var CONTACT_EMAIL = document.getElementById("emailLink")
    ? document.getElementById("emailLink").textContent.trim()
    : "contacto@tudominio.com";

  if (form) {
    form.addEventListener("submit", function (e) {
      e.preventDefault();

      var nombre = form.nombre.value.trim();
      var correo = form.correo.value.trim();
      var servicio = form.servicio.value;
      var mensaje = form.mensaje.value.trim();

      if (!nombre || !correo || !mensaje) {
        note.textContent = "Por favor completa nombre, correo y mensaje.";
        return;
      }

      var subject = "Consulta de servicio: " + servicio;
      var body =
        "Nombre: " + nombre + "\n" +
        "Correo: " + correo + "\n" +
        "Servicio de interés: " + servicio + "\n\n" +
        "Mensaje:\n" + mensaje;

      var mailto =
        "mailto:" + encodeURIComponent(CONTACT_EMAIL) +
        "?subject=" + encodeURIComponent(subject) +
        "&body=" + encodeURIComponent(body);

      window.location.href = mailto;
      note.textContent = "Abriendo tu cliente de correo para enviar el mensaje...";
    });
  }
})();
