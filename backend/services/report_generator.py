"""
Minimal incident report PDF for first-response paramedics.
Single-page triage sheet + transcript appendix + QR code for mobile download.
"""
from __future__ import annotations

from datetime import datetime
from io import BytesIO
import re
from typing import Any, Optional

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
    PageBreak,
    HRFlowable,
    Image as RLImage,
    KeepTogether,
)

# ---------------------------------------------------------------------------
# Palette — minimal: monochrome + urgency accent
# ---------------------------------------------------------------------------
DARK = colors.HexColor("#1a1a1a")
MID = colors.HexColor("#444444")
LIGHT_TEXT = colors.HexColor("#777777")
RULE_COLOR = colors.HexColor("#d0d0d0")
ALT_ROW = colors.HexColor("#f6f6f6")
WHITE = colors.white

RED = colors.HexColor("#b71c1c")
ORANGE = colors.HexColor("#e65100")
AMBER = colors.HexColor("#f57f17")
GREEN = colors.HexColor("#1b5e20")
DARK_BG = colors.HexColor("#212121")

URGENCY_BG = {"low": GREEN, "medium": AMBER, "high": ORANGE, "critical": RED}
URGENCY_FG = {"low": WHITE, "medium": DARK, "high": WHITE, "critical": WHITE}

# ---------------------------------------------------------------------------
# Vitals reference
# ---------------------------------------------------------------------------
VITALS_META = {
    "hr":   ("HR",    "bpm",  60,   100),
    "rr":   ("RR",    "/min", 12,   20),
    "spo2": ("SpO2",  "%",    95,   100),
    "gcs":  ("GCS",   "/15",  13,   15),
    "sbp":  ("BP",    "mmHg", 90,   140),
    "temp": ("Temp",  "C",    36.1, 37.8),
}

# ---------------------------------------------------------------------------
# Field investigation protocols (diagnosis-matched)
# ---------------------------------------------------------------------------
FIELD_INVESTIGATIONS: dict[str, list[dict[str, str]]] = {
    "cardiac arrest": [
        {"check": "Attach AED / defibrillator pads", "equip": "AED", "look_for": "Shockable rhythm (VF/pVT) vs non-shockable (PEA/asystole)"},
        {"check": "Capnography (EtCO2)", "equip": "Capnometer", "look_for": "EtCO2 >10 mmHg = effective CPR; sudden rise = ROSC"},
        {"check": "12-lead ECG", "equip": "Cardiac monitor", "look_for": "ST elevation, arrhythmia, heart block"},
        {"check": "Blood glucose", "equip": "Glucometer", "look_for": "Hypoglycemia <60 mg/dL as reversible cause"},
        {"check": "Pupil response", "equip": "Penlight", "look_for": "Fixed dilated = poor prognosis; asymmetry = stroke"},
    ],
    "cardiac": [
        {"check": "12-lead ECG", "equip": "Cardiac monitor", "look_for": "ST elevation/depression, T-wave changes, arrhythmia"},
        {"check": "BP both arms", "equip": "BP cuff", "look_for": ">20 mmHg difference may indicate aortic dissection"},
        {"check": "SpO2", "equip": "Pulse oximeter", "look_for": "<94% = hypoxia; give supplemental O2"},
        {"check": "Blood glucose", "equip": "Glucometer", "look_for": "Rule out hypoglycemia mimicking cardiac symptoms"},
        {"check": "Lung auscultation", "equip": "Stethoscope", "look_for": "Crackles = pulmonary edema; absent = pneumothorax"},
    ],
    "stroke": [
        {"check": "Cincinnati / FAST scale", "equip": "Clinical", "look_for": "Facial droop, arm drift, speech difficulty"},
        {"check": "Blood glucose", "equip": "Glucometer", "look_for": "Hypoglycemia mimics stroke -- must rule out first"},
        {"check": "Blood pressure", "equip": "BP cuff", "look_for": "Crisis >220/120; do NOT lower aggressively in acute stroke"},
        {"check": "Pupil response", "equip": "Penlight", "look_for": "Unequal pupils = herniation; document for ER"},
        {"check": "Time of onset", "equip": "Interview", "look_for": "<4.5 hrs = thrombolysis candidate; document EXACT time"},
    ],
    "respiratory": [
        {"check": "SpO2 + waveform", "equip": "Pulse oximeter", "look_for": "<90% = severe; <94% = supplemental O2"},
        {"check": "Capnography", "equip": "Capnometer", "look_for": "EtCO2 >45 = hypoventilation; low = hyperventilation"},
        {"check": "Lung auscultation", "equip": "Stethoscope", "look_for": "Wheezing, stridor, crackles, absent sounds"},
        {"check": "Peak flow", "equip": "Peak flow meter", "look_for": "<200 L/min = severe bronchospasm"},
        {"check": "Blood glucose", "equip": "Glucometer", "look_for": "Metabolic cause of tachypnea (DKA)"},
    ],
    "trauma": [
        {"check": "C-spine immobilization", "equip": "Cervical collar", "look_for": "Mechanism suggests spinal injury -- immobilize first"},
        {"check": "Blood pressure", "equip": "BP cuff", "look_for": "Systolic <90 = hemorrhagic shock; start fluids"},
        {"check": "Bilateral breath sounds", "equip": "Stethoscope", "look_for": "Absent one side = pneumothorax; needle decompression"},
        {"check": "GCS assessment", "equip": "Clinical (E+V+M)", "look_for": "<8 = intubate; document for trauma team"},
        {"check": "Hemorrhage control", "equip": "Gauze / tourniquet", "look_for": "Active bleed: direct pressure; extremity = tourniquet"},
    ],
    "seizure": [
        {"check": "Blood glucose STAT", "equip": "Glucometer", "look_for": "Hypoglycemia <60 -- give dextrose/glucagon immediately"},
        {"check": "SpO2", "equip": "Pulse oximeter", "look_for": "Postictal desaturation common; suction + O2"},
        {"check": "Temperature", "equip": "Thermometer", "look_for": "Febrile seizure if >38C (esp. pediatric)"},
        {"check": "12-lead ECG", "equip": "Cardiac monitor", "look_for": "Prolonged QT, Brugada pattern"},
        {"check": "Pupil response", "equip": "Penlight", "look_for": "Asymmetry = structural lesion vs metabolic"},
    ],
    "allergic": [
        {"check": "Lung auscultation", "equip": "Stethoscope", "look_for": "Stridor = upper airway; wheezing = lower airway"},
        {"check": "Blood pressure", "equip": "BP cuff", "look_for": "Hypotension = anaphylaxis; give epinephrine IM"},
        {"check": "SpO2", "equip": "Pulse oximeter", "look_for": "Desaturation = airway compromise"},
        {"check": "Skin assessment", "equip": "Visual", "look_for": "Urticaria, angioedema, cyanosis distribution"},
    ],
    "diabetic": [
        {"check": "Blood glucose STAT", "equip": "Glucometer", "look_for": "<60 = hypoglycemia (glucose/dextrose); >300 = DKA/HHS"},
        {"check": "Ketones", "equip": "Urine strips", "look_for": "Positive + glucose >250 = likely DKA"},
        {"check": "12-lead ECG", "equip": "Cardiac monitor", "look_for": "Peaked T waves = hyperkalemia (life-threatening in DKA)"},
        {"check": "Respiratory pattern", "equip": "Clinical", "look_for": "Kussmaul breathing = metabolic acidosis / DKA"},
    ],
    "poisoning": [
        {"check": "Blood glucose", "equip": "Glucometer", "look_for": "Many toxins cause hypoglycemia"},
        {"check": "Pupil assessment", "equip": "Penlight", "look_for": "Pinpoint = opioid; dilated = sympathomimetic"},
        {"check": "12-lead ECG", "equip": "Cardiac monitor", "look_for": "Wide QRS = Na-channel blocker; prolonged QT"},
        {"check": "SpO2 + capnography", "equip": "Pulse ox + capnometer", "look_for": "Hypoventilation (opioids) vs hyperventilation (salicylates)"},
        {"check": "Temperature", "equip": "Thermometer", "look_for": "Hyperthermia = serotonin syndrome"},
    ],
    "burn": [
        {"check": "TBSA estimate (Rule of 9s)", "equip": "Clinical", "look_for": ">20% TBSA or airway burns = fluid resuscitation"},
        {"check": "Airway assessment", "equip": "Stethoscope + penlight", "look_for": "Singed nasal hair, soot, stridor = inhalation injury"},
        {"check": "SpO2 / CO-oximetry", "equip": "Pulse oximeter", "look_for": "Normal SpO2 can be falsely reassuring in CO poisoning"},
        {"check": "IV + fluid calc", "equip": "IV kit", "look_for": "Parkland: 4mL x kg x %TBSA / 24h (half in first 8h)"},
    ],
    "choking": [
        {"check": "Airway patency", "equip": "Laryngoscope + Magill forceps", "look_for": "Visible foreign body -- remove under direct vision"},
        {"check": "SpO2", "equip": "Pulse oximeter", "look_for": "Desaturation trend; prepare surgical airway if complete obstruction"},
        {"check": "Auscultation", "equip": "Stethoscope", "look_for": "Stridor = partial; silence = complete obstruction"},
    ],
}

DEFAULT_FIELD_INVESTIGATIONS = [
    {"check": "Blood glucose", "equip": "Glucometer", "look_for": "Hypo/hyperglycemia as contributing factor"},
    {"check": "SpO2 monitoring", "equip": "Pulse oximeter", "look_for": "<94% supplement O2; <90% critical"},
    {"check": "Blood pressure", "equip": "BP cuff", "look_for": "Hypo/hypertension; guide fluid resuscitation"},
    {"check": "12-lead ECG", "equip": "Cardiac monitor", "look_for": "Arrhythmia, ischemia, electrolyte abnormality"},
    {"check": "Pupil response", "equip": "Penlight", "look_for": "Size, equality, reactivity"},
    {"check": "Temperature", "equip": "Thermometer", "look_for": "Fever (infection/sepsis) or hypothermia"},
    {"check": "GCS assessment", "equip": "Clinical (E+V+M)", "look_for": "Consciousness trend; <8 = secure airway"},
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _esc(text: str) -> str:
    """Escape XML entities for ReportLab Paragraph markup."""
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _clean_msg(text: str) -> str:
    """Strip system-injected context prefixes from user messages."""
    text = re.sub(r"\[Camera observation:.*?\]\s*", "", text)
    text = re.sub(r"\[Vision detection:.*?\]\s*", "", text)
    text = re.sub(r"\[Action verified:.*?\]\s*", "", text)
    return text.strip()


def _match_field_investigations(diagnosis: Optional[str], findings: list) -> list:
    if not diagnosis:
        return DEFAULT_FIELD_INVESTIGATIONS
    text = (diagnosis + " " + " ".join(findings)).lower()
    for keyword, checks in FIELD_INVESTIGATIONS.items():
        if keyword in text:
            return checks
    for keyword, checks in FIELD_INVESTIGATIONS.items():
        for word in keyword.split():
            if word in text and len(word) > 3:
                return checks
    return DEFAULT_FIELD_INVESTIGATIONS


def _generate_qr_code_image(url: str) -> Optional[BytesIO]:
    try:
        import qrcode
        qr = qrcode.QRCode(version=1, error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=8, border=2)
        qr.add_data(url)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        buf = BytesIO()
        img.save(buf, format="PNG")
        buf.seek(0)
        return buf
    except ImportError:
        return None


def _duration_str(start_iso: str, end_iso: Optional[str]) -> str:
    """Human-readable duration between two ISO timestamps."""
    try:
        fmt = "%Y-%m-%dT%H:%M:%S"
        s = datetime.strptime(start_iso[:19], fmt)
        if end_iso and end_iso != "Ongoing":
            e = datetime.strptime(end_iso[:19], fmt)
        else:
            e = datetime.utcnow()
        delta = int((e - s).total_seconds())
        if delta < 0:
            delta = 0
        mins, secs = divmod(delta, 60)
        return f"{mins}m {secs:02d}s"
    except Exception:
        return "--"


# ---------------------------------------------------------------------------
# Styles (kept minimal)
# ---------------------------------------------------------------------------

def _styles():
    ss = getSampleStyleSheet()
    add = ss.add

    add(ParagraphStyle("RepTitle", parent=ss["Heading1"], fontName="Helvetica-Bold",
                        fontSize=14, textColor=DARK, leading=17, spaceAfter=0, spaceBefore=0))
    add(ParagraphStyle("RepSub", parent=ss["Normal"], fontSize=8, textColor=LIGHT_TEXT,
                        leading=10, spaceAfter=2))
    add(ParagraphStyle("RepSection", parent=ss["Normal"], fontName="Helvetica-Bold",
                        fontSize=9, textColor=MID, leading=12, spaceBefore=8, spaceAfter=3))
    add(ParagraphStyle("RepBody", parent=ss["Normal"], fontSize=8.5, textColor=DARK,
                        leading=12, spaceAfter=2))
    add(ParagraphStyle("RepSmall", parent=ss["Normal"], fontSize=7.5, textColor=MID,
                        leading=10, spaceAfter=1))
    add(ParagraphStyle("RepFoot", parent=ss["Normal"], fontSize=6.5, textColor=LIGHT_TEXT,
                        leading=8, alignment=TA_CENTER, spaceAfter=0))
    add(ParagraphStyle("TxRole", parent=ss["Normal"], fontName="Helvetica-Bold",
                        fontSize=7.5, textColor=MID, leading=9, spaceAfter=0))
    add(ParagraphStyle("TxLine", parent=ss["Normal"], fontSize=7.5, textColor=DARK,
                        leading=10, spaceAfter=4))
    add(ParagraphStyle("BandLg", parent=ss["Normal"], fontName="Helvetica-Bold",
                        fontSize=18, textColor=WHITE, alignment=TA_CENTER, leading=22))
    add(ParagraphStyle("BandMd", parent=ss["Normal"], fontName="Helvetica-Bold",
                        fontSize=11, textColor=WHITE, alignment=TA_CENTER, leading=14))
    add(ParagraphStyle("BandSm", parent=ss["Normal"], fontName="Helvetica-Bold",
                        fontSize=10, textColor=WHITE, alignment=TA_CENTER, leading=13))
    add(ParagraphStyle("QrLabel", parent=ss["Normal"], fontName="Helvetica-Bold",
                        fontSize=8, textColor=MID, alignment=TA_CENTER, leading=10))
    return ss


# ---------------------------------------------------------------------------
# Data extraction helpers
# ---------------------------------------------------------------------------

def _build_briefing(
    user_msgs: list[dict],
    primary_diagnosis: str,
    confidence: int,
    findings: list[str],
    call_emergency: bool,
    guided_actions: list[str],
) -> str:
    """Synthesize a short narrative from session data."""
    parts: list[str] = []
    if user_msgs:
        first = _esc(_clean_msg(user_msgs[0].get("text", "")))[:250]
        if first:
            parts.append(f'Bystander reported: "{first}"')
    for m in user_msgs[1:3]:
        extra = _esc(_clean_msg(m.get("text", "")))[:120]
        if extra:
            parts.append(f'Also stated: "{extra}"')
    if primary_diagnosis != "Undetermined":
        parts.append(f"AI assessment: <b>{_esc(primary_diagnosis)}</b> ({confidence}% confidence).")
    if findings:
        parts.append("Findings: " + ", ".join(_esc(f) for f in findings[:5]) + ".")
    if call_emergency:
        parts.append("<b>911 was flagged as required.</b>")
    if guided_actions:
        parts.append(f"Bystander was guided through {len(guided_actions)} action(s) before EMS arrival.")
    return " ".join(parts) if parts else "No situation data recorded."


def _extract_guided_actions(assistant_msgs: list[dict], meta_list: list[dict]) -> list[str]:
    """Pull concise action descriptions from AI guidance messages."""
    actions: list[str] = []
    for i, m in enumerate(assistant_msgs):
        meta = meta_list[i] if i < len(meta_list) else {}
        text = (m.get("text") or "").strip()
        if not text:
            continue
        urg = meta.get("urgency", "low")
        has_diag = bool(meta.get("diagnosis"))
        if urg in ("high", "critical") or has_diag:
            actions.append(text[:150])
    return actions


# ---------------------------------------------------------------------------
# PDF generation
# ---------------------------------------------------------------------------

def generate_pdf(session: dict, download_url: Optional[str] = None) -> bytes:
    buf = BytesIO()
    PAGE_W, PAGE_H = letter
    MARGIN = 0.5 * inch
    USABLE_W = PAGE_W - 2 * MARGIN

    doc = SimpleDocTemplate(buf, pagesize=letter,
                            leftMargin=MARGIN, rightMargin=MARGIN,
                            topMargin=MARGIN, bottomMargin=MARGIN)
    s = _styles()
    story: list = []

    # -- Parse session data ------------------------------------------------
    meta_list: list[dict] = session.get("metadata_list") or []
    messages: list[dict] = session.get("messages") or []
    user_msgs = [m for m in messages if m.get("role") == "user"]
    assistant_msgs = [m for m in messages if m.get("role") == "assistant"]

    diagnoses = [m.get("diagnosis") for m in meta_list if m.get("diagnosis")]
    urgencies = [m.get("urgency") for m in meta_list if m.get("urgency")]
    all_findings: list[str] = []
    for m in meta_list:
        all_findings.extend(m.get("key_findings") or [])
    confidences = [m.get("confidence", 0) for m in meta_list if m.get("confidence")]
    call_emergency = any(m.get("call_emergency") for m in meta_list)

    primary_diagnosis = diagnoses[-1] if diagnoses else "Undetermined"
    urgency = urgencies[-1] if urgencies else "medium"
    confidence = confidences[-1] if confidences else 0
    unique_findings = list(dict.fromkeys(all_findings))
    urg_bg = URGENCY_BG.get(urgency, AMBER)
    urg_fg = URGENCY_FG.get(urgency, WHITE)

    vitals: dict[str, float] = {}
    for m in meta_list:
        for k in VITALS_META:
            if k in m:
                vitals[k] = m[k]
    for m in messages:
        if isinstance(m.get("vitals"), dict):
            vitals.update(m["vitals"])

    report_id = session.get("session_id", "unknown")[:8].upper()
    start_iso = session.get("start_time", "")
    end_iso = session.get("end_time")
    start_display = start_iso[:19].replace("T", " ") if start_iso else "--"
    duration = _duration_str(start_iso, end_iso)
    guided_actions = _extract_guided_actions(assistant_msgs, meta_list)

    # =====================================================================
    # PAGE 1 — TRIAGE SHEET
    # =====================================================================

    # -- 1. Header ---------------------------------------------------------
    story.append(Paragraph("CRISIS COPILOT  INCIDENT REPORT", s["RepTitle"]))
    story.append(Paragraph(
        f"ID: <b>{report_id}</b>  |  {start_display} UTC  |  Duration: <b>{duration}</b>  |  "
        f"Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M')} UTC",
        s["RepSub"],
    ))
    story.append(Spacer(1, 4))

    # -- 2. Urgency band ---------------------------------------------------
    band_data = [[
        Paragraph(urgency.upper(), ParagraphStyle("_bu", parent=s["BandLg"], textColor=urg_fg)),
        Paragraph(
            f"{_esc(primary_diagnosis)}  |  {confidence}% conf",
            s["BandMd"],
        ),
        Paragraph(
            "911: YES" if call_emergency else "911: NO",
            ParagraphStyle("_be", parent=s["BandSm"],
                           textColor=WHITE),
        ),
    ]]
    band = Table(band_data, colWidths=[1.4 * inch, 4.4 * inch, 1.7 * inch])
    band.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, 0), urg_bg),
        ("BACKGROUND", (1, 0), (1, 0), DARK_BG),
        ("BACKGROUND", (2, 0), (2, 0), RED if call_emergency else GREEN),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 10),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ]))
    story.append(band)
    story.append(Spacer(1, 6))

    # -- 3. Vitals (inline) ------------------------------------------------
    if vitals:
        parts: list[str] = []
        for key in ("hr", "rr", "spo2", "gcs", "sbp", "temp"):
            val = vitals.get(key)
            if val is None:
                continue
            label, unit, lo, hi = VITALS_META[key]
            val_str = f"{val:.1f}" if key == "temp" else str(int(val))
            abnormal = val < lo or val > hi
            if abnormal:
                parts.append(f'<b><font color="#b71c1c">{label}: {val_str}{unit} !!</font></b>')
            else:
                parts.append(f"{label}: {val_str}{unit}")
        if parts:
            story.append(Paragraph("VITALS   " + "   |   ".join(parts), s["RepBody"]))
            story.append(Spacer(1, 2))

    # -- 4. Key findings ---------------------------------------------------
    if unique_findings:
        bullets = "   ".join(f"<b>* {_esc(f)}</b>" for f in unique_findings[:6])
        story.append(Paragraph(f"KEY FINDINGS   {bullets}", s["RepBody"]))
        story.append(Spacer(1, 2))

    story.append(HRFlowable(width="100%", thickness=0.5, color=RULE_COLOR, spaceAfter=4, spaceBefore=2))

    # -- 5. Situation briefing ---------------------------------------------
    story.append(Paragraph("SITUATION BRIEFING", s["RepSection"]))
    briefing = _build_briefing(user_msgs, primary_diagnosis, confidence,
                               unique_findings, call_emergency, guided_actions)
    story.append(Paragraph(briefing, s["RepBody"]))

    # -- 6. Actions taken --------------------------------------------------
    if guided_actions:
        story.append(Paragraph("ACTIONS GUIDED BY AI", s["RepSection"]))
        for i, action in enumerate(guided_actions[:6], 1):
            story.append(Paragraph(f"{i}. {_esc(action)}", s["RepSmall"]))

    story.append(HRFlowable(width="100%", thickness=0.5, color=RULE_COLOR, spaceAfter=4, spaceBefore=6))

    # -- 7. Field diagnostics checklist ------------------------------------
    story.append(Paragraph("FIELD DIAGNOSTICS  --  PRE-HOSPITAL CHECKLIST", s["RepSection"]))
    investigations = _match_field_investigations(primary_diagnosis, unique_findings)

    diag_header = [
        Paragraph("<b>Investigation</b>", s["RepSmall"]),
        Paragraph("<b>Equipment</b>", s["RepSmall"]),
        Paragraph("<b>Look For</b>", s["RepSmall"]),
    ]
    diag_rows = [diag_header]
    for item in investigations:
        diag_rows.append([
            Paragraph(f"[ ]  {_esc(item['check'])}", s["RepSmall"]),
            Paragraph(_esc(item["equip"]), s["RepSmall"]),
            Paragraph(_esc(item["look_for"]), s["RepSmall"]),
        ])

    diag_table = Table(diag_rows, colWidths=[2.2 * inch, 1.3 * inch, 4.0 * inch])
    diag_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#eeeeee")),
        ("LINEBELOW", (0, 0), (-1, 0), 0.5, RULE_COLOR),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [WHITE, ALT_ROW]),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LINEBELOW", (0, -1), (-1, -1), 0.5, RULE_COLOR),
    ]))
    story.append(diag_table)
    story.append(Spacer(1, 8))

    # -- 8. QR code --------------------------------------------------------
    if download_url:
        story.append(HRFlowable(width="100%", thickness=0.5, color=RULE_COLOR, spaceAfter=6))
        qr_buf = _generate_qr_code_image(download_url)
        if qr_buf:
            qr_img = RLImage(qr_buf, width=1.2 * inch, height=1.2 * inch)
            qr_img.hAlign = "CENTER"
            story.append(Paragraph("SCAN TO DOWNLOAD THIS REPORT ON YOUR PHONE", s["QrLabel"]))
            story.append(Spacer(1, 2))
            story.append(qr_img)
            story.append(Spacer(1, 2))
            story.append(Paragraph(
                f'<font color="#777777">{_esc(download_url)}</font>',
                ParagraphStyle("_qr_url", parent=s["RepSmall"], alignment=TA_CENTER),
            ))
            story.append(Spacer(1, 4))

    # -- 9. Disclaimer (compact) -------------------------------------------
    story.append(Paragraph(
        "Auto-generated by Crisis Copilot AI. Not a medical device. "
        "Verify all findings independently. For emergencies call local services.",
        s["RepFoot"],
    ))

    # =====================================================================
    # PAGE 2+ — FULL TRANSCRIPT  (bold = clinically significant)
    # =====================================================================
    story.append(PageBreak())
    story.append(Paragraph("FULL TRANSCRIPT", s["RepTitle"]))
    story.append(Paragraph(
        f"Session {report_id}  |  {start_display} UTC  |  {len(messages)} messages",
        s["RepSub"],
    ))
    story.append(HRFlowable(width="100%", thickness=0.5, color=RULE_COLOR, spaceAfter=6))

    # Pre-compute which assistant messages are clinically significant
    assistant_sig: dict[int, bool] = {}
    a_idx = 0
    for m in messages:
        if m.get("role") == "assistant":
            meta = meta_list[a_idx] if a_idx < len(meta_list) else {}
            sig = (
                bool(meta.get("diagnosis"))
                or bool(meta.get("key_findings"))
                or meta.get("call_emergency", False)
                or meta.get("urgency") in ("high", "critical")
            )
            assistant_sig[a_idx] = sig
            a_idx += 1

    a_counter = 0
    for i, m in enumerate(messages):
        role = m.get("role", "user")
        raw_text = (m.get("text") or "").strip()
        if not raw_text:
            continue
        ts = m.get("timestamp", "")[:19].replace("T", " ")
        clean = _esc(_clean_msg(raw_text) if role == "user" else raw_text)
        clean = clean.replace("\n", " ")

        is_significant = False
        if role == "user" and i == 0:
            is_significant = True
        elif role == "assistant":
            is_significant = assistant_sig.get(a_counter, False)
            a_counter += 1

        if role == "user":
            label_color = "#1565c0"
            label = "BYSTANDER"
        else:
            label_color = "#2e7d32"
            label = "AI"

        story.append(Paragraph(
            f'<font color="{label_color}"><b>[{label}]</b></font>'
            f'  <font color="#999999">{ts}</font>',
            s["TxRole"],
        ))
        if is_significant:
            story.append(Paragraph(f"<b>{clean}</b>", s["TxLine"]))
        else:
            story.append(Paragraph(clean, s["TxLine"]))

    if not messages:
        story.append(Paragraph("No messages recorded.", s["RepSmall"]))

    # -- Build PDF ---------------------------------------------------------
    doc.build(story)
    return buf.getvalue()
