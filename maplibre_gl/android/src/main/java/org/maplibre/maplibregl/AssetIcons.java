package org.maplibre.maplibregl;

import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.DisplayMetrics;

import androidx.annotation.Nullable;

import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.NavigableSet;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Loads an icon the style names by its Flutter asset path, such as {@code assets/pins/pin.png}.
 *
 * <p>With resolution variants ({@code 2.0x/pin.png}, {@code 3.0x/pin.png}) the icon is sized like
 * {@code Image.asset}: the file nearest the screen density, drawn at its own ratio, the main file
 * at 1. A file without variants keeps the addImage default, one image pixel per device pixel.
 * MapLibreMapController.swift and the web loader do the same.
 */
final class AssetIcons {
  // A variant folder as Flutter's asset bundler names them: 2.0x, 3x, 1.5x.
  private static final Pattern VARIANT_FOLDER = Pattern.compile("(\\d+(\\.\\d*)?)x");

  private AssetIcons() {}

  /**
   * The icon at {@code mainPath}, a path in the APK assets, or null when neither the file nor a
   * variant of it exists.
   */
  @Nullable
  static Bitmap load(AssetManager assets, String mainPath, float density) {
    int slash = mainPath.lastIndexOf('/');
    String folder = slash < 0 ? "" : mainPath.substring(0, slash);
    String fileName = mainPath.substring(slash + 1);

    // Ratio to path. A 1.0x folder replaces the main file, as in Flutter.
    TreeMap<Float, String> files = new TreeMap<>();
    List<String> children = list(assets, folder);
    if (children.contains(fileName)) {
      files.put(1f, mainPath);
    }
    boolean hasVariants = false;
    for (String child : children) {
      Matcher match = VARIANT_FOLDER.matcher(child);
      String childFolder = folder.isEmpty() ? child : folder + "/" + child;
      if (!match.matches() || !list(assets, childFolder).contains(fileName)) {
        continue;
      }
      float ratio = Float.parseFloat(match.group(1));
      if (ratio > 0) {
        files.put(ratio, childFolder + "/" + fileName);
        hasVariants = true;
      }
    }
    if (files.isEmpty()) {
      return null;
    }

    float ratio = bestRatio(files.navigableKeySet(), density);
    Bitmap bitmap;
    try (InputStream stream = assets.open(files.get(ratio))) {
      bitmap = BitmapFactory.decodeStream(stream);
    } catch (IOException e) {
      return null;
    }
    // Decoded as is, the bitmap has the screen density, which MapLibre takes as its pixel ratio.
    if (bitmap != null && hasVariants) {
      bitmap.setDensity(Math.round(ratio * DisplayMetrics.DENSITY_DEFAULT));
    }
    return bitmap;
  }

  /**
   * The ratio Flutter's AssetImage picks: the exact one, else below a density of 2 the next larger
   * one, which upscales less, and above it the nearest one.
   */
  static float bestRatio(NavigableSet<Float> ratios, float density) {
    if (ratios.contains(density)) {
      return density;
    }
    Float lower = ratios.lower(density);
    Float upper = ratios.higher(density);
    if (lower == null) {
      return upper;
    }
    if (upper == null) {
      return lower;
    }
    return density < 2 || density > (lower + upper) / 2 ? upper : lower;
  }

  private static List<String> list(AssetManager assets, String folder) {
    try {
      String[] names = assets.list(folder);
      return names == null ? Collections.emptyList() : Arrays.asList(names);
    } catch (IOException e) {
      return Collections.emptyList();
    }
  }
}
