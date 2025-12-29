// ========================================
// PUZZLE BOX GENERATOR - Interactive Script
// ========================================

const API_BASE = window.location.origin;

document.addEventListener('DOMContentLoaded', () => {
    initSliders();
    initFormSubmission();
    initAnimations();
    initMazeRowsCalculator();
    checkServerHealth();
});

// ========================================
// MAZE ROWS CALCULATOR
// ========================================

function initMazeRowsCalculator() {
    const heightInput = document.getElementById('h');
    const mazeSpacingInput = document.getElementById('z');
    const baseHeightInput = document.getElementById('b');
    const mazeMarginInput = document.getElementById('M');
    
    // Calculate on any relevant input change
    const updateMazeRows = () => {
        calculateMazeRows();
    };
    
    if (heightInput) {
        heightInput.addEventListener('input', updateMazeRows);
    }
    if (mazeSpacingInput) {
        mazeSpacingInput.addEventListener('input', updateMazeRows);
    }
    if (baseHeightInput) {
        baseHeightInput.addEventListener('input', updateMazeRows);
    }
    if (mazeMarginInput) {
        mazeMarginInput.addEventListener('input', updateMazeRows);
    }
    
    // Initial calculation
    calculateMazeRows();
}

function calculateMazeRows() {
    const heightInput = document.getElementById('h');
    const mazeSpacingInput = document.getElementById('z');
    const baseHeightInput = document.getElementById('b');
    const mazeMarginInput = document.getElementById('M');
    const mazeRowsDisplay = document.getElementById('mazeRowsCount');
    
    if (!mazeRowsDisplay) return;
    
    // Get values with defaults matching the C generator
    const height = parseFloat(heightInput?.value) || 50;
    const mazeStep = parseFloat(mazeSpacingInput?.value) || 3;
    const baseHeight = parseFloat(baseHeightInput?.value) || 10;
    const mazeMargin = parseFloat(mazeMarginInput?.value) || 1;
    const basethickness = 1.6; // Default from C code
    
    // Formula from C code: H = (height - base - mazemargin) / mazestep
    // where base = baseHeight + basethickness (approximately)
    const availableHeight = height - baseHeight - basethickness - mazeMargin;
    const rows = Math.max(1, Math.floor(availableHeight / mazeStep));
    
    mazeRowsDisplay.textContent = rows;
    
    // Add visual feedback based on difficulty
    const indicator = mazeRowsDisplay.closest('.maze-rows-indicator');
    if (indicator) {
        indicator.classList.remove('easy', 'medium', 'hard', 'extreme');
        if (rows <= 5) {
            indicator.classList.add('easy');
        } else if (rows <= 10) {
            indicator.classList.add('medium');
        } else if (rows <= 15) {
            indicator.classList.add('hard');
        } else {
            indicator.classList.add('extreme');
        }
    }
}

// ========================================
// SERVER HEALTH CHECK
// ========================================

async function checkServerHealth() {
    try {
        const response = await fetch(`${API_BASE}/api/health`);
        const data = await response.json();
        
        if (data.status === 'ok') {
            if (data.generator) {
                showNotification('Ready to generate puzzle boxes!', 'success');
            } else {
                showNotification('Generator not found. Please check setup.', 'error');
            }
        }
    } catch (error) {
        // Server not running
        console.log('Server not available');
    }
}

// ========================================
// SLIDER FUNCTIONALITY
// ========================================

function initSliders() {
    const sliders = document.querySelectorAll('input[type="range"]');
    
    sliders.forEach(slider => {
        const output = document.querySelector(`output[for="${slider.id}"]`);
        
        if (output) {
            // Set initial value
            output.textContent = slider.value;
            
            // Update on change
            slider.addEventListener('input', () => {
                output.textContent = slider.value;
                
                // Add visual feedback
                const value = parseInt(slider.value);
                if (value < 0) {
                    output.style.color = 'var(--accent-alt)';
                } else if (value > 0) {
                    output.style.color = 'var(--accent-primary)';
                } else {
                    output.style.color = 'var(--text-muted)';
                }
            });
        }
    });
}

// ========================================
// FORM SUBMISSION
// ========================================

function initFormSubmission() {
    const form = document.getElementById('puzzleForm');
    const downloadBtn = document.getElementById('downloadBtn');
    
    if (downloadBtn) {
        downloadBtn.addEventListener('click', async (e) => {
            e.preventDefault();
            
            // Always use MakerWorld format
            const format = 'makerworld';
            
            // Visual feedback - show loading
            downloadBtn.classList.add('generating');
            const originalTitle = downloadBtn.querySelector('.btn-title').textContent;
            const originalDesc = downloadBtn.querySelector('.btn-desc').textContent;
            downloadBtn.querySelector('.btn-title').textContent = 'Generating...';
            downloadBtn.querySelector('.btn-desc').textContent = 'Creating code for MakerWorld...';
            downloadBtn.disabled = true;
            
            try {
                await generatePuzzleBox(format);
            } finally {
                // Reset button state
                downloadBtn.classList.remove('generating');
                downloadBtn.querySelector('.btn-title').textContent = originalTitle;
                downloadBtn.querySelector('.btn-desc').textContent = originalDesc;
                downloadBtn.disabled = false;
            }
        });
    }
    
    // Update button appearance when format changes
    const formatRadios = document.querySelectorAll('input[name="format"]');
    formatRadios.forEach(radio => {
        radio.addEventListener('change', updateDownloadButton);
    });
    updateDownloadButton(); // Set initial state
}

function updateDownloadButton() {
    const downloadBtn = document.getElementById('downloadBtn');
    
    if (downloadBtn) {
        const btnIcon = downloadBtn.querySelector('.btn-icon');
        const btnTitle = downloadBtn.querySelector('.btn-title');
        const btnDesc = downloadBtn.querySelector('.btn-desc');
        
        btnIcon.textContent = '🌐';
        btnTitle.textContent = 'Generate Code';
        btnDesc.textContent = 'Get code for MakerWorld';
    }
}

async function generatePuzzleBox(format) {
    const form = document.getElementById('puzzleForm');
    
    // Build URL parameters
    const params = new URLSearchParams();
    
    // Add format flag
    if (format === 'stl') {
        params.append('l', '1');
    } else if (format === 'makerworld') {
        params.append('polyhedron', '1');
    }
    
    // Collect all form values
    const inputs = form.querySelectorAll('input');
    
    inputs.forEach(input => {
        const name = input.name;
        
        if (!name || name === 'format') return;
        
        if (input.type === 'checkbox') {
            if (input.checked) {
                params.append(name, '1');
            }
        } else if (input.type === 'range') {
            params.append(name, input.value);
        } else if (input.value && input.value.trim() !== '') {
            params.append(name, input.value.trim());
        }
    });
    
    // Also collect select values
    const selects = form.querySelectorAll('select');
    selects.forEach(select => {
        const name = select.name;
        if (name && select.value) {
            params.append(name, select.value);
        }
    });
    
    // Try local API first
    try {
        const response = await fetch(`${API_BASE}/api/generate?${params.toString()}`);
        
        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            throw new Error(errorData.error || `Server error: ${response.status}`);
        }
        
        // Handle MakerWorld format - display parts separately for individual copy/paste
        if (format === 'makerworld') {
            const data = await response.json();
            if (data.parts && data.parts.length > 0) {
                showPartsModal(data.parts, data.full_scad, data.share_id);
                showNotification(`${data.parts.length} part(s) ready - copy each separately!`, 'success');
                
                // Also show share ID in the main input
                if (data.share_id) {
                    showShareId(data.share_id);
                }
            } else if (data.error) {
                showNotification(`Error: ${data.error}`, 'error');
            } else {
                showNotification('Failed to generate code.', 'warning');
            }
            return;
        }
        
        // Get filename from Content-Disposition header
        const contentDisposition = response.headers.get('Content-Disposition');
        let filename = format === 'stl' ? 'puzzlebox.stl' : 'puzzlebox.scad';
        
        if (contentDisposition) {
            const filenameMatch = contentDisposition.match(/filename="?([^"]+)"?/);
            if (filenameMatch) {
                filename = filenameMatch[1];
            }
        }
        
        // Download the file
        const blob = await response.blob();
        downloadBlob(blob, filename);
        
        showNotification(`${format.toUpperCase()} file generated successfully!`, 'success');
        
    } catch (error) {
        console.error('Generation error:', error);
        
        if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
            showNotification('Server not running. Please start the server first.', 'error');
        } else if (error.message.includes('openscad') || error.message.includes('Qt') || error.message.includes('processor')) {
            showNotification('STL generation failed. Try OpenSCAD format instead, then export to STL in the app.', 'error');
        } else {
            showNotification(`Error: ${error.message}`, 'error');
        }
    }
}

// ========================================
// SCAD CODE MODAL
// ========================================

function showPartsModal(parts, fullScad, shareId) {
    const modal = document.getElementById('codeModal');
    const codeBlocks = document.getElementById('codeBlocks');
    
    // Clear previous content
    codeBlocks.innerHTML = '';
    
    // Add share ID section
    if (shareId) {
        const shareDiv = document.createElement('div');
        shareDiv.className = 'share-id-box';
        shareDiv.innerHTML = `
            <div class="share-id-header">
                <span class="share-id-label">🔗 Share ID (save to regenerate this exact puzzle)</span>
                <button type="button" class="copy-btn small" onclick="copyShareId(this, '${shareId}')">
                    <span class="copy-icon">📋</span>
                    <span class="copy-text">Copy</span>
                </button>
            </div>
            <code class="share-id-value">${shareId}</code>
        `;
        codeBlocks.appendChild(shareDiv);
    }
    
    // Add info about copying parts separately
    const infoDiv = document.createElement('div');
    infoDiv.className = 'parts-info';
    infoDiv.innerHTML = `
        <p><strong>💡 Tip:</strong> Copy each part separately to avoid MakerWorld timeout errors.</p>
    `;
    codeBlocks.appendChild(infoDiv);
    
    // Create a code block for each part
    parts.forEach((part, index) => {
        const block = document.createElement('div');
        block.className = 'code-block';
        
        const charCount = part.code.length.toLocaleString();
        
        block.innerHTML = `
            <div class="code-block-header">
                <span class="code-block-title">${part.name} <span class="char-count">(${charCount} chars)</span></span>
                <button type="button" class="copy-btn" onclick="copyPartCode(this, ${index})">
                    <span class="copy-icon">📋</span>
                    <span class="copy-text">Copy ${part.name}</span>
                </button>
            </div>
            <pre class="code-content" id="part-code-${index}">${escapeHtml(part.code)}</pre>
        `;
        
        codeBlocks.appendChild(block);
    });
    
    
    // Show modal
    modal.style.display = 'flex';
    document.body.style.overflow = 'hidden';
}

function showScadModal(scadContent) {
    const modal = document.getElementById('codeModal');
    const codeBlocks = document.getElementById('codeBlocks');
    
    // Clear previous content
    codeBlocks.innerHTML = '';
    
    // Create a single code block with the full SCAD content
    const block = document.createElement('div');
    block.className = 'code-block';
    
    block.innerHTML = `
        <div class="code-block-header">
            <span class="code-block-title">Complete OpenSCAD Code</span>
            <button type="button" class="copy-btn" onclick="copyScadCode(this)">
                <span class="copy-icon">📋</span>
                <span class="copy-text">Copy All</span>
            </button>
        </div>
        <pre class="code-content" id="scad-code">${escapeHtml(scadContent)}</pre>
    `;
    
    codeBlocks.appendChild(block);
    
    // Show modal
    modal.style.display = 'flex';
    document.body.style.overflow = 'hidden';
}

// Keep old function for backwards compatibility
function showPolyhedronModal(polyhedrons) {
    const modal = document.getElementById('codeModal');
    const codeBlocks = document.getElementById('codeBlocks');
    
    codeBlocks.innerHTML = '';
    
    polyhedrons.forEach((poly, index) => {
        const block = document.createElement('div');
        block.className = 'code-block';
        
        block.innerHTML = `
            <div class="code-block-header">
                <span class="code-block-title">${poly.name}</span>
                <button type="button" class="copy-btn" onclick="copyCode(this, ${index})">
                    <span class="copy-icon">📋</span>
                    <span class="copy-text">Copy</span>
                </button>
            </div>
            <pre class="code-content" id="code-${index}">${escapeHtml(poly.code)}</pre>
        `;
        
        codeBlocks.appendChild(block);
    });
    
    modal.style.display = 'flex';
    document.body.style.overflow = 'hidden';
}

function closeCodeModal() {
    const modal = document.getElementById('codeModal');
    modal.style.display = 'none';
    document.body.style.overflow = '';
}

async function copyCode(button, index) {
    const codeElement = document.getElementById(`code-${index}`);
    const code = codeElement.textContent;
    await copyToClipboard(button, code, 'Copy');
}

async function copyScadCode(button) {
    const codeElement = document.getElementById('scad-code');
    const code = codeElement.textContent;
    await copyToClipboard(button, code, 'Copy All');
}

async function copyPartCode(button, index) {
    const codeElement = document.getElementById(`part-code-${index}`);
    const code = codeElement.textContent;
    const partName = `Copy Part ${index + 1}`;
    await copyToClipboard(button, code, partName);
}

async function copyFullScad(button) {
    // Get the full code from the data attribute
    const block = button.closest('.code-block');
    const fullCode = block.dataset.fullCode;
    await copyToClipboard(button, fullCode, 'Copy All');
}

async function copyShareId(button, shareId) {
    await copyToClipboard(button, shareId, 'Copy');
}

async function copyToClipboard(button, code, originalText) {
    try {
        await navigator.clipboard.writeText(code);
        button.querySelector('.copy-text').textContent = 'Copied!';
        button.classList.add('copied');
        
        setTimeout(() => {
            button.querySelector('.copy-text').textContent = originalText;
            button.classList.remove('copied');
        }, 2000);
    } catch (err) {
        // Fallback for older browsers
        const textarea = document.createElement('textarea');
        textarea.value = code;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        
        button.querySelector('.copy-text').textContent = 'Copied!';
        setTimeout(() => {
            button.querySelector('.copy-text').textContent = originalText;
        }, 2000);
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Close modal on backdrop click
document.addEventListener('click', (e) => {
    if (e.target.classList.contains('modal-backdrop')) {
        closeCodeModal();
    }
});

// Close modal on Escape key
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeCodeModal();
    }
});

function downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}

// ========================================
// NOTIFICATIONS
// ========================================

function showNotification(message, type = 'info') {
    // Remove existing notifications
    const existing = document.querySelector('.notification');
    if (existing) {
        existing.remove();
    }
    
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    
    const icons = {
        info: '◈',
        success: '✓',
        error: '✕',
        warning: '⚠'
    };
    
    notification.innerHTML = `
        <span class="notification-icon">${icons[type] || icons.info}</span>
        <span class="notification-message">${message}</span>
    `;
    
    // Add styles if not already added
    if (!document.getElementById('notification-styles')) {
        const styles = document.createElement('style');
        styles.id = 'notification-styles';
        styles.textContent = `
            .notification {
                position: fixed;
                bottom: 2rem;
                right: 2rem;
                display: flex;
                align-items: center;
                gap: 0.75rem;
                padding: 1rem 1.5rem;
                background: rgba(22, 22, 32, 0.95);
                border: 1px solid rgba(255, 255, 255, 0.1);
                border-radius: 12px;
                backdrop-filter: blur(20px);
                box-shadow: 0 20px 60px -15px rgba(0, 0, 0, 0.5);
                z-index: 1000;
                animation: slideInUp 0.4s cubic-bezier(0.4, 0, 0.2, 1);
                max-width: 400px;
            }
            
            @keyframes slideInUp {
                from {
                    opacity: 0;
                    transform: translateY(20px);
                }
                to {
                    opacity: 1;
                    transform: translateY(0);
                }
            }
            
            .notification-info {
                border-color: var(--accent-primary);
            }
            
            .notification-success {
                border-color: #10b981;
            }
            
            .notification-error {
                border-color: #ef4444;
            }
            
            .notification-warning {
                border-color: #f59e0b;
            }
            
            .notification-icon {
                font-size: 1.25rem;
                color: var(--accent-primary);
            }
            
            .notification-success .notification-icon {
                color: #10b981;
            }
            
            .notification-error .notification-icon {
                color: #ef4444;
            }
            
            .notification-message {
                font-size: 0.9rem;
                color: var(--text-primary);
            }
            
            .generate-btn.generating {
                opacity: 0.7;
                pointer-events: none;
            }
            
            .generate-btn.generating .btn-icon {
                animation: pulse 1s ease-in-out infinite;
            }
            
            @keyframes pulse {
                0%, 100% { opacity: 1; }
                50% { opacity: 0.5; }
            }
        `;
        document.head.appendChild(styles);
    }
    
    document.body.appendChild(notification);
    
    // Auto-remove after 5 seconds (longer for errors)
    const duration = type === 'error' ? 8000 : 5000;
    setTimeout(() => {
        notification.style.animation = 'slideInUp 0.3s cubic-bezier(0.4, 0, 0.2, 1) reverse';
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, duration);
}

// ========================================
// ANIMATIONS & INTERACTIONS
// ========================================

function initAnimations() {
    // Intersection Observer for scroll animations
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };
    
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
            }
        });
    }, observerOptions);
    
    // Observe all form sections
    document.querySelectorAll('.form-section').forEach(section => {
        observer.observe(section);
    });
    
    // Add hover effects to input fields
    const inputs = document.querySelectorAll('.input-field input');
    inputs.forEach(input => {
        input.addEventListener('focus', () => {
            input.closest('.input-field')?.classList.add('focused');
        });
        
        input.addEventListener('blur', () => {
            input.closest('.input-field')?.classList.remove('focused');
        });
    });
    
    // Add ripple effect to buttons
    const buttons = document.querySelectorAll('.generate-btn');
    buttons.forEach(button => {
        button.addEventListener('click', function(e) {
            const rect = button.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            
            const ripple = document.createElement('span');
            ripple.className = 'ripple';
            ripple.style.left = `${x}px`;
            ripple.style.top = `${y}px`;
            
            this.appendChild(ripple);
            
            setTimeout(() => {
                ripple.remove();
            }, 600);
        });
    });
    
    // Add ripple styles
    if (!document.getElementById('ripple-styles')) {
        const styles = document.createElement('style');
        styles.id = 'ripple-styles';
        styles.textContent = `
            .generate-btn {
                position: relative;
                overflow: hidden;
            }
            
            .ripple {
                position: absolute;
                width: 10px;
                height: 10px;
                background: rgba(255, 255, 255, 0.3);
                border-radius: 50%;
                transform: translate(-50%, -50%) scale(0);
                animation: ripple 0.6s linear;
                pointer-events: none;
            }
            
            @keyframes ripple {
                to {
                    transform: translate(-50%, -50%) scale(40);
                    opacity: 0;
                }
            }
            
            .input-field.focused label {
                color: var(--accent-primary);
            }
            
            .form-section.visible {
                opacity: 1;
                transform: translateY(0);
            }
        `;
        document.head.appendChild(styles);
    }
}

// ========================================
// KEYBOARD SHORTCUTS
// ========================================

document.addEventListener('keydown', (e) => {
    // Ctrl/Cmd + Enter to generate
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
        e.preventDefault();
        generatePuzzleBox('makerworld');
    }
});

// Clear any old localStorage data and use hardcoded defaults from original site
localStorage.removeItem('puzzleBoxForm');

// ========================================
// PRESET CONFIGURATIONS
// ========================================

const PRESETS = {
    simple: {
        m: '2', c: '30', h: '50', X: '0', N: '2', H: '2'
    },
    challenging: {
        m: '3', c: '35', h: '60', X: '5', N: '2', H: '2', i: true
    },
    extreme: {
        m: '4', c: '40', h: '70', X: '10', N: '3', H: '3', i: true, f: true
    },
    gift: {
        m: '2', c: '25', h: '40', X: '3', N: '2', H: '2', s: '8'
    }
};

function applyPreset(presetName) {
    const preset = PRESETS[presetName];
    if (!preset) return;
    
    const form = document.getElementById('puzzleForm');
    
    // Reset all inputs first
    form.querySelectorAll('input').forEach(input => {
        if (input.type === 'checkbox') {
            input.checked = false;
        } else if (input.type !== 'range') {
            input.value = '';
        }
    });
    
    // Apply preset values
    Object.entries(preset).forEach(([name, value]) => {
        const input = form.querySelector(`[name="${name}"]`);
        if (input) {
            if (input.type === 'checkbox') {
                input.checked = !!value;
            } else {
                input.value = value;
            }
        }
    });
    
    // Update sliders and maze rows
    initSliders();
    calculateMazeRows();
    
    showNotification(`Applied "${presetName}" preset`, 'info');
}

// ========================================
// SHARE ID FUNCTIONS
// ========================================

async function importShareId() {
    const shareInput = document.getElementById('shareId');
    const shareId = shareInput.value.trim();
    
    if (!shareId) {
        showNotification('Please enter a Share ID', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/api/decode?id=${encodeURIComponent(shareId)}`);
        const data = await response.json();
        
        if (data.error) {
            showNotification(`Invalid Share ID: ${data.error}`, 'error');
            return;
        }
        
        if (data.params) {
            // Apply all parameters to the form
            const form = document.getElementById('puzzleForm');
            
            Object.entries(data.params).forEach(([key, value]) => {
                const input = form.querySelector(`[name="${key}"]`);
                if (input) {
                    if (input.type === 'checkbox') {
                        input.checked = value === '1' || value === 'true' || value === 'on';
                    } else {
                        input.value = value;
                    }
                }
                
                // Also check selects
                const select = form.querySelector(`select[name="${key}"]`);
                if (select) {
                    select.value = value;
                }
            });
            
            // Update sliders display and maze rows
            initSliders();
            calculateMazeRows();
            
            showNotification('Settings restored from Share ID!', 'success');
            shareInput.value = '';  // Clear the input
        }
    } catch (error) {
        showNotification('Failed to decode Share ID', 'error');
    }
}

function showShareId(shareId) {
    const shareInput = document.getElementById('shareId');
    if (shareInput) {
        shareInput.value = shareId;
        shareInput.select();
    }
}

// Expose to global scope for potential preset buttons and modal
window.applyPreset = applyPreset;
window.closeCodeModal = closeCodeModal;
window.copyCode = copyCode;
window.copyScadCode = copyScadCode;
window.copyPartCode = copyPartCode;
window.copyFullScad = copyFullScad;
window.importShareId = importShareId;
window.copyShareId = copyShareId;
