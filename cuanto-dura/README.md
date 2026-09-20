# ¿Cuánto Dura? — app nativa (Capacitor)

Envoltorio nativo de `index.html` para iOS y Android via [Capacitor](https://capacitorjs.com).

- **App ID:** `com.ferry.applications.howlong`
- **Web (Pages):** https://ferryapplications.github.io/juegos/cuanto-dura/
- La fuente de verdad del juego sigue siendo `index.html` en esta carpeta (mismo fichero que sirve la web).

## Desarrollo

```bash
npm install
npm run sync      # copia index.html -> www/ y sincroniza Capacitor
npx cap open android   # abre Android Studio
npx cap open ios       # abre Xcode
```

Cada vez que cambie `index.html`, ejecuta `npm run sync` antes de abrir/compilar los proyectos nativos.

## CI

`.github/workflows/android.yml` e `ios.yml` (en la raíz del repo) compilan un APK debug y una build de simulador en cada push a `main` que toque esta carpeta — es solo validación de que compila, no genera builds firmadas para las tiendas. Eso (certificados, provisioning, claves de App Store Connect / Play Console) queda pendiente para cuando se quiera publicar de verdad.
