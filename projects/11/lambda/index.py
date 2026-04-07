import json
import os
import logging
import boto3

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

translate  = boto3.client("translate")
comprehend = boto3.client("comprehend")

target_language = os.environ["TARGET_LANGUAGE"]


def handler(event, context):
    path = event.get("rawPath", "")
    body = json.loads(event.get("body", "{}"))

    if path.endswith("/translate"):
        return handle_translate(body)

    if path.endswith("/analyze"):
        return handle_analyze(body)

    return response(404, {"error": "Route not found"})


# ── Translate — Detect language and translate ────────────────

def handle_translate(body):
    """
    Detects the source language automatically and translates
    the text to the configured target language.
    """
    text   = body.get("text", "").strip()
    target = body.get("target_language", target_language)

    if not text:
        return response(400, {"error": "Field 'text' is required"})

    result = translate.translate_text(
        Text               = text,
        SourceLanguageCode = "auto", # Auto-detect source language
        TargetLanguageCode = target
    )

    logger.info("Translated from %s to %s", result["SourceLanguageCode"], target)

    return response(200, {
        "original_text":     text,
        "translated_text":   result["TranslatedText"],
        "source_language":   result["SourceLanguageCode"],
        "target_language":   target
    })


# ── Analyze — Translate + full Comprehend analysis ───────────

def handle_analyze(body):
    """
    Detects language, translates to English and runs a full
    Comprehend analysis: sentiment, entities and key phrases.
    """
    text = body.get("text", "").strip()

    if not text:
        return response(400, {"error": "Field 'text' is required"})

    # Step 1 — Detect dominant language
    language_result = comprehend.detect_dominant_language(Text=text)
    source_language = language_result["Languages"][0]["LanguageCode"]

    # Step 2 — Translate to English for consistent analysis
    translated = translate.translate_text(
        Text               = text,
        SourceLanguageCode = source_language,
        TargetLanguageCode = "en"
    )
    translated_text = translated["TranslatedText"]

    # Step 3 — Run Comprehend on the translated text
    sentiment = comprehend.detect_sentiment(
        Text         = translated_text,
        LanguageCode = "en"
    )

    entities = comprehend.detect_entities(
        Text         = translated_text,
        LanguageCode = "en"
    )

    key_phrases = comprehend.detect_key_phrases(
        Text         = translated_text,
        LanguageCode = "en"
    )

    logger.info("Analyzed text: lang=%s, sentiment=%s", source_language, sentiment["Sentiment"])

    return response(200, {
        "original_text":   text,
        "translated_text": translated_text,
        "source_language": source_language,
        "sentiment":       sentiment["Sentiment"],
        "scores":          sentiment["SentimentScore"],
        "entities":        [{"text": e["Text"], "type": e["Type"]} for e in entities["Entities"]],
        "key_phrases":     [p["Text"] for p in key_phrases["KeyPhrases"]]
    })


# ── Utility ──────────────────────────────────────────────────

def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers":    {"Content-Type": "application/json"},
        "body":       json.dumps(body, default=str)
    }
