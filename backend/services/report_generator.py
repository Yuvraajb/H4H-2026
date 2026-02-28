"""
Report Generator - Workstream D
Generates PDF reports from session data using ReportLab.
"""
from typing import Dict, Any, Optional
from datetime import datetime
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_CENTER, TA_LEFT
import io

class ReportGenerator:
    def __init__(self):
        self.styles = getSampleStyleSheet()

    def generate_pdf(self, session_data: Dict[str, Any]) -> bytes:
        """
        Generate a PDF report from session data.
        
        Args:
            session_data: Session dictionary with transcript, metadata, etc.
        
        Returns:
            PDF file as bytes
        """
        # Create a BytesIO buffer for the PDF
        buffer = io.BytesIO()
        
        # Create the PDF document
        doc = SimpleDocTemplate(
            buffer,
            pagesize=letter,
            rightMargin=72,
            leftMargin=72,
            topMargin=72,
            bottomMargin=18,
        )

        # Build the PDF content
        story = []

        # Title
        title_style = ParagraphStyle(
            'CustomTitle',
            parent=self.styles['Heading1'],
            fontSize=24,
            textColor='#1a1a1a',
            spaceAfter=30,
            alignment=TA_CENTER,
        )
        story.append(Paragraph("GuideVR Session Report", title_style))
        story.append(Spacer(1, 0.2 * inch))

        # Session Info
        info_style = ParagraphStyle(
            'Info',
            parent=self.styles['Normal'],
            fontSize=10,
            textColor='#666666',
        )
        
        session_id = session_data.get("id", "Unknown")
        mode = session_data.get("mode", "live")
        start_time = session_data.get("start_time", "Unknown")
        
        story.append(Paragraph(f"<b>Session ID:</b> {session_id}", info_style))
        story.append(Paragraph(f"<b>Mode:</b> {mode.title()}", info_style))
        story.append(Paragraph(f"<b>Start Time:</b> {start_time}", info_style))
        
        if session_data.get("end_time"):
            story.append(Paragraph(f"<b>End Time:</b> {session_data['end_time']}", info_style))
        
        story.append(Spacer(1, 0.3 * inch))

        # Transcript Section
        story.append(Paragraph("<b>Transcript</b>", self.styles['Heading2']))
        story.append(Spacer(1, 0.1 * inch))

        transcript = session_data.get("transcript", [])
        if transcript:
            for entry in transcript:
                speaker = entry.get("speaker", "unknown").title()
                text = entry.get("text", "")
                timestamp = entry.get("timestamp", "")
                
                speaker_style = ParagraphStyle(
                    'Speaker',
                    parent=self.styles['Normal'],
                    fontSize=10,
                    textColor='#0066cc' if speaker == "User" else '#009900',
                    fontName='Helvetica-Bold',
                )
                
                story.append(Paragraph(f"<b>{speaker}:</b> {text}", speaker_style))
                story.append(Paragraph(f"<i>{timestamp}</i>", info_style))
                story.append(Spacer(1, 0.1 * inch))
        else:
            story.append(Paragraph("No transcript entries.", self.styles['Normal']))

        story.append(Spacer(1, 0.2 * inch))

        # Metadata Section
        metadata = session_data.get("metadata", [])
        if metadata:
            story.append(Paragraph("<b>Session Metadata</b>", self.styles['Heading2']))
            story.append(Spacer(1, 0.1 * inch))
            
            for meta in metadata:
                step = meta.get("step", "?")
                urgency = meta.get("urgency", "unknown")
                category = meta.get("category", "unknown")
                display_text = meta.get("display_text", "")
                
                story.append(Paragraph(
                    f"<b>Step {step}:</b> {display_text} (Urgency: {urgency}, Category: {category})",
                    self.styles['Normal']
                ))
                story.append(Spacer(1, 0.05 * inch))

        # Summary
        story.append(Spacer(1, 0.2 * inch))
        story.append(Paragraph(
            f"<b>Summary:</b> This session contained {len(transcript)} transcript entries and {len(metadata)} metadata entries.",
            self.styles['Normal']
        ))

        # Build PDF
        doc.build(story)
        
        # Get the PDF bytes
        pdf_bytes = buffer.getvalue()
        buffer.close()
        
        return pdf_bytes

    def generate_report_file(
        self,
        session_data: Dict[str, Any],
        output_path: str
    ) -> str:
        """
        Generate PDF and save to file.
        
        Returns:
            Path to the generated PDF file
        """
        pdf_bytes = self.generate_pdf(session_data)
        
        with open(output_path, 'wb') as f:
            f.write(pdf_bytes)
        
        return output_path
