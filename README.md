# Juegos

Prototipos de juegos de estimación y percepción.

## Juegos

- [**¿Cuánto Dura?**](./cuanto-dura/) — adivina la duración real de cosas cotidianas y curiosas, modo diario con racha y comparativa global.

## Estructura

- `cuanto-dura/` — juego autocontenido en un único `index.html` (sin build).
- `backend/schema.sql` — esquema de Supabase (RLS + funciones RPC) compartido por los juegos que necesiten guardar partidas/rachas sin login.

## Publicación

La web se sirve vía GitHub Pages desde la raíz de `main`.

## Apps nativas

`cuanto-dura/` incluye un proyecto [Capacitor](https://capacitorjs.com) (`android/`, `ios/`) que envuelve el mismo `index.html`. Ver `cuanto-dura/README.md` para desarrollo local. CI de compilación en `.github/workflows/android.yml` e `ios.yml`.
