package tv.dumbtv.home;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;

/**
 * Background › Blurred artwork: the focused app's art, shrunk and blurred into a backdrop like
 * Apple TV's. Plain box blur on a 64×36 copy, no RenderScript or RenderEffect, so it runs on
 * Fire OS 6 too; the ImageView's bilinear scaling smooths the rest.
 */
final class Backdrop {
    private static final int W = 64, H = 36, RADIUS = 3, PASSES = 3;

    private Backdrop() {}

    static Bitmap from(Drawable art) {
        if (art == null || art.getConstantState() == null) return null;
        try {
            Drawable copy = art.getConstantState().newDrawable().mutate();
            Bitmap bitmap = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888);
            Canvas canvas = new Canvas(bitmap);
            canvas.drawColor(0xFF000000);
            // Cover the frame: square icons are scaled to the full width and centered.
            int iw = Math.max(1, copy.getIntrinsicWidth()), ih = Math.max(1, copy.getIntrinsicHeight());
            float scale = Math.max(W / (float) iw, H / (float) ih);
            int dw = Math.round(iw * scale), dh = Math.round(ih * scale);
            int left = (W - dw) / 2, top = (H - dh) / 2;
            copy.setBounds(left, top, left + dw, top + dh);
            copy.draw(canvas);
            int[] px = new int[W * H];
            bitmap.getPixels(px, 0, W, 0, 0, W, H);
            for (int i = 0; i < PASSES; i++) blur(px);
            bitmap.setPixels(px, 0, W, 0, 0, W, H);
            return bitmap;
        } catch (RuntimeException ignored) {
            return null;
        }
    }

    /** One horizontal and one vertical box pass, edges clamped. */
    private static void blur(int[] px) {
        int[] tmp = new int[px.length];
        for (int y = 0; y < H; y++) {
            for (int x = 0; x < W; x++) tmp[y * W + x] = average(px, x, y, 1, 0);
        }
        for (int y = 0; y < H; y++) {
            for (int x = 0; x < W; x++) px[y * W + x] = average(tmp, x, y, 0, 1);
        }
    }

    private static int average(int[] px, int x, int y, int dx, int dy) {
        int r = 0, g = 0, b = 0, n = 0;
        for (int k = -RADIUS; k <= RADIUS; k++) {
            int sx = Math.max(0, Math.min(W - 1, x + k * dx));
            int sy = Math.max(0, Math.min(H - 1, y + k * dy));
            int p = px[sy * W + sx];
            r += (p >> 16) & 255;
            g += (p >> 8) & 255;
            b += p & 255;
            n++;
        }
        return 0xFF000000 | (r / n) << 16 | (g / n) << 8 | (b / n);
    }
}
