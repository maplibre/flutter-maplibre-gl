package android.util;

import java.io.PrintWriter;
import java.io.StringWriter;

/**
 * Stands in for android.util.Log in the JVM unit tests, where every method of the android.jar
 * they compile against throws "not mocked". The classes of the tests come before that jar on the
 * test classpath, so the code under test logs through this class instead, to stderr.
 *
 * <p>It has the methods the code under test calls and a few common ones. Code that calls one
 * missing here fails with a NoSuchMethodError, which points straight at this file.
 */
public final class Log {
  private Log() {}

  public static int d(String tag, String msg) {
    return print("D", tag, msg, null);
  }

  public static int w(String tag, String msg) {
    return print("W", tag, msg, null);
  }

  public static int e(String tag, String msg) {
    return print("E", tag, msg, null);
  }

  public static int e(String tag, String msg, Throwable tr) {
    return print("E", tag, msg, tr);
  }

  public static String getStackTraceString(Throwable tr) {
    if (tr == null) {
      return "";
    }
    final StringWriter writer = new StringWriter();
    tr.printStackTrace(new PrintWriter(writer));
    return writer.toString();
  }

  private static int print(String level, String tag, String msg, Throwable tr) {
    final String line = level + "/" + tag + ": " + msg;
    System.err.println(tr == null ? line : line + "\n" + getStackTraceString(tr));
    return line.length();
  }
}
