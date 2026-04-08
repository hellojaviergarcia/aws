import json
import os
import logging
import boto3

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

rekognition = boto3.client("rekognition")
comprehend  = boto3.client("comprehend")
transcribe  = boto3.client("transcribe")

bucket_name         = os.environ["BUCKET_NAME"]
transcribe_language = os.environ["TRANSCRIBE_LANGUAGE"]


def handler(event, context):
    path = event.get("rawPath", "")
    body = json.loads(event.get("body", "{}"))

    if path.endswith("/analyze/image"):
        return analyze_image(body)

    if path.endswith("/analyze/text"):
        return analyze_text(body)

    if path.endswith("/analyze/audio"):
        return analyze_audio(body)

    return response(404, {"error": "Route not found"})


# ── Rekognition ; Image analysis ────────────────────────────

def analyze_image(body):
    """
    Analyzes an image stored in S3 using Rekognition.
    Detects labels, text and moderation flags.
    """
    s3_key = body.get("s3_key")

    if not s3_key:
        return response(400, {"error": "Field 's3_key' is required"})

    # Detect labels (objects, scenes, activities)
    labels_result = rekognition.detect_labels(
        Image={"S3Object": {"Bucket": bucket_name, "Name": s3_key}},
        MaxLabels=10,
        MinConfidence=70
    )

    # Detect text in the image
    text_result = rekognition.detect_text(
        Image={"S3Object": {"Bucket": bucket_name, "Name": s3_key}}
    )

    # Detect moderation labels (unsafe content)
    moderation_result = rekognition.detect_moderation_labels(
        Image={"S3Object": {"Bucket": bucket_name, "Name": s3_key}},
        MinConfidence=70
    )

    result = {
        "labels":           [{"name": l["Name"], "confidence": round(l["Confidence"], 2)} for l in labels_result["Labels"]],
        "detected_text":    [t["DetectedText"] for t in text_result["TextDetections"] if t["Type"] == "LINE"],
        "moderation_flags": [m["Name"] for m in moderation_result["ModerationLabels"]]
    }

    logger.info("Image analyzed: %s labels, %s text lines", len(result["labels"]), len(result["detected_text"]))
    return response(200, result)


# ── Comprehend ; Text analysis ───────────────────────────────

def analyze_text(body):
    """
    Analyzes text using Comprehend.
    Detects sentiment, entities, key phrases and language.
    """
    text = body.get("text", "").strip()

    if not text:
        return response(400, {"error": "Field 'text' is required"})

    # Detect dominant language first
    language_result = comprehend.detect_dominant_language(Text=text)
    language_code   = language_result["Languages"][0]["LanguageCode"]

    # Detect sentiment (POSITIVE, NEGATIVE, NEUTRAL, MIXED)
    sentiment_result = comprehend.detect_sentiment(Text=text, LanguageCode=language_code)

    # Detect named entities (people, places, organizations)
    entities_result = comprehend.detect_entities(Text=text, LanguageCode=language_code)

    # Detect key phrases
    phrases_result = comprehend.detect_key_phrases(Text=text, LanguageCode=language_code)

    result = {
        "language":   language_code,
        "sentiment":  sentiment_result["Sentiment"],
        "scores":     sentiment_result["SentimentScore"],
        "entities":   [{"text": e["Text"], "type": e["Type"]} for e in entities_result["Entities"]],
        "key_phrases": [p["Text"] for p in phrases_result["KeyPhrases"]]
    }

    logger.info("Text analyzed: sentiment=%s, entities=%s", result["sentiment"], len(result["entities"]))
    return response(200, result)


# ── Transcribe ; Audio transcription ─────────────────────────

def analyze_audio(body):
    """
    Starts an Amazon Transcribe job for an audio file stored in S3.
    Returns the job name to poll for results.
    """
    import time

    s3_key   = body.get("s3_key")
    job_name = f"transcribe-{int(time.time())}"

    if not s3_key:
        return response(400, {"error": "Field 's3_key' is required"})

    transcribe.start_transcription_job(
        TranscriptionJobName = job_name,
        Media                = {"MediaFileUri": f"s3://{bucket_name}/{s3_key}"},
        LanguageCode         = transcribe_language,
        OutputBucketName     = bucket_name,
        OutputKey            = f"transcriptions/{job_name}.json"
    )

    logger.info("Transcription job started: %s", job_name)

    return response(202, {
        "job_name": job_name,
        "message":  "Transcription job started. Check S3 for results.",
        "output":   f"s3://{bucket_name}/transcriptions/{job_name}.json"
    })


# ── Utility ──────────────────────────────────────────────────

def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers":    {"Content-Type": "application/json"},
        "body":       json.dumps(body, default=str)
    }
