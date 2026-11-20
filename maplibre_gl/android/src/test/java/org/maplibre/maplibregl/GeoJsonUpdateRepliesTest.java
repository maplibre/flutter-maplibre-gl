package org.maplibre.maplibregl;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.junit.Test;

/** The replies to GeoJSON data changes go when the engine applies the data, in its order. */
public class GeoJsonUpdateRepliesTest {
  private final GeoJsonUpdateReplies replies = new GeoJsonUpdateReplies();
  private final List<String> sent = new ArrayList<>();

  private void add(String sourceId, String name) {
    replies.add(sourceId, () -> sent.add(name));
  }

  @Test
  public void aReplyWaitsUntilTheEngineAppliesItsData() {
    add("s", "a");

    assertTrue(sent.isEmpty());
    replies.applied("s");

    assertEquals(Arrays.asList("a"), sent);
    assertFalse(replies.isWaiting("s"));
  }

  @Test
  public void changesThatComeDuringAConversionGoWhenTheLastOfThemIsApplied() {
    add("s", "a");
    add("s", "b");
    add("s", "c");

    // The engine applies a, then converts only c, the last waiting change.
    replies.applied("s");
    assertEquals(Arrays.asList("a"), sent);
    assertTrue(replies.isWaiting("s"));

    replies.applied("s");
    assertEquals(Arrays.asList("a", "b", "c"), sent);
    assertFalse(replies.isWaiting("s"));
  }

  @Test
  public void aChangeAfterTheLastConversionStartsANewOne() {
    add("s", "a");
    replies.applied("s");
    add("s", "b");

    assertEquals(Arrays.asList("a"), sent);
    replies.applied("s");
    assertEquals(Arrays.asList("a", "b"), sent);
  }

  @Test
  public void eachSourceWaitsForItsOwnData() {
    add("s", "a");
    add("t", "b");

    replies.applied("t");
    assertEquals(Arrays.asList("b"), sent);
    replies.applied("s");
    assertEquals(Arrays.asList("b", "a"), sent);
  }

  @Test
  public void anEventForASourceWithNoWaitingReplyDoesNothing() {
    replies.applied("s");
    add("s", "a");

    assertTrue(sent.isEmpty());
    replies.applied("s");
    assertEquals(Arrays.asList("a"), sent);
  }

  @Test
  public void releaseRunsTheRepliesOfOneSource() {
    add("s", "a");
    add("s", "b");
    add("t", "c");

    replies.release("s");

    assertEquals(Arrays.asList("a", "b"), sent);
    assertFalse(replies.isWaiting("s"));
    assertTrue(replies.isWaiting("t"));
  }

  @Test
  public void releaseAllRunsEveryReply() {
    add("s", "a");
    add("t", "b");

    replies.releaseAll();

    assertEquals(2, sent.size());
    assertFalse(replies.isWaiting("s"));
    assertFalse(replies.isWaiting("t"));
  }
}
