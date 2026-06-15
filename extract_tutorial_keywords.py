#!/usr/bin/env python3
"""
extract_tutorial_keywords.py
============================
Scans all hndsd.js files under the launcher directory tree, extracts search words
from the oWl array, filters them (≥ MIN_TOPICS occurrences), groups them by
launcher section, and updates the <script id="searchKeywords"> block in index.html.

The mapping from filesystem path to launcher section is defined in PATH_TO_SECTION.
To add a new tutorial, just add a new entry there and re-run.

Usage:
    python extract_tutorial_keywords.py            # dry-run (shows what would change)
    python extract_tutorial_keywords.py --apply     # actually update index.html
"""

import os
import re
import json
import sys
from collections import defaultdict

# === CONFIGURATION ===

LAUNCHER_DIR = r"C:\Proyectos\launcher"
INDEX_HTML   = os.path.join(LAUNCHER_DIR, "index.html")

# Minimum number of topics a word must appear in (within a single hndsd.js) to be kept
MIN_TOPICS = 10

# Minimum word length
MIN_WORD_LEN = 5

# Only keep words that are purely alphabetic (no numbers, symbols, percentages)
# This filters out "1500", "100%", "120°", "690v", etc.
ALPHA_ONLY = re.compile(r'^[a-záéíóúüñàâèêëïîôùûçäöüßãõ]+$', re.IGNORECASE)

# --- PATH-TO-SECTION MAPPING ---
# Each key is a relative path (from LAUNCHER_DIR) to a directory containing js/hndsd.js.
# Each value is the launcher section ID where those keywords should navigate to.
# Add new tutorials here as they are created.
PATH_TO_SECTION = {
    # English
    "simulators/en/DSAS-tutorial-preview":      "sim-dsas",
    "simulators/en/DSAS-practical-exercises":    "sim-dsas",
    "simulators/en/Experiments":                 "tutorials",
    # Spanish
    "simulators/es/DSAS-tutorial-preview":       "sim-dsas",
    "simulators/es/Experiments":                 "tutorials",
    # French
    "simulators/fr/DSAS-tutorial-preview":       "sim-dsas",
    "simulators/fr/French":                      "tutorials",
}

# The original hand-written keywords that should always be preserved.
# These are kept as-is and the extracted ones are appended after them.
MANUAL_KEYWORDS = [
    { "keywords": ["wind energy", "introduction", "concepts", "turbine basics"], "section": "concepts" },
    { "keywords": ["wind turbine families", "DFIG", "active stall", "rotor resistance", "full converter", "squirrel cage"], "section": "concepts" },
    { "keywords": ["scada", "wind farm", "control center", "substation", "grid"], "section": "windfarm" },
    { "keywords": ["simulator", "real-time", "training"], "section": "simulators" },
    { "keywords": ["drive train", "operational curve", "MPPT", "gearbox", "blade rpm"], "section": "drivetrain" },
    { "keywords": ["back-to-back", "B2B", "converter", "power electronics", "DFIG B2B"], "section": "b2b" },
    { "keywords": ["video", "demonstration", "youtube"], "section": "videos" },
    { "keywords": ["tutorial", "learning", "teaching"], "section": "tutorials" },
    { "keywords": ["download", "install", "evaluation", "license", "free trial"], "section": "downloads" },
    { "keywords": ["yaw system", "yaw drive", "yaw motor", "nacelle"], "section": "windfarm" },
    { "keywords": ["pitch", "blade angle", "stall control"], "section": "simulators" },
    { "keywords": ["wind gust", "gusts", "rafaga"], "section": "simulators" },
]

# Words to always exclude — common function words in EN/ES/FR that have no
# domain-specific search value.  Technical/domain terms are NOT listed here.
STOP_WORDS = {
    # --- English function words / very common verbs ---
    'a', 'able', 'about', 'above', 'according', 'account', 'across', 'action',
    'actions', 'actual', 'actually', 'added', 'after', 'again', 'against', 'ago',
    'ahead', 'aiming', 'allow', 'allowed', 'allowing', 'allows', 'almost',
    'along', 'already', 'also', 'although', 'always', 'among', 'amount', 'and',
    'another', 'answer', 'any', 'anyway', 'anything', 'appear', 'appears',
    'application', 'applied', 'applies', 'apply', 'approach', 'approaches',
    'appropriate', 'are', 'area', 'areas', 'around', 'aspect', 'aspects',
    'associated', 'assume', 'assuming', 'attempt', 'available', 'away',
    'back', 'based', 'basic', 'basically', 'basis', 'became', 'because',
    'become', 'becomes', 'been', 'before', 'begin', 'beginning', 'begins',
    'being', 'below', 'best', 'better', 'between', 'beyond', 'black', 'blue',
    'both', 'bottom', 'briefly', 'bring', 'brings', 'button', 'call', 'called',
    'calls', 'came', 'can', 'cannot', 'capable', 'carry', 'case', 'cases',
    'cause', 'caused', 'causes', 'certain', 'certainly', 'change', 'changed',
    'changes', 'changing', 'check', 'checks', 'choose', 'chosen', 'clear',
    'clearly', 'click', 'clicking', 'close', 'closed', 'closer', 'color',
    'column', 'come', 'comes', 'coming', 'command', 'commands', 'common',
    'commonly', 'compare', 'compared', 'complete', 'completely', 'complex',
    'concern', 'concerned', 'concerning', 'conclusion', 'condition',
    'conditions', 'configuration', 'confirmed', 'consider', 'considered',
    'consist', 'consists', 'constant', 'contain', 'containing', 'contains',
    'context', 'continue', 'continues', 'continuous', 'continuously', 'control',
    'controls', 'conventional', 'correct', 'correctly', 'correspond',
    'corresponding', 'corresponds', 'copyright', 'could', 'couple', 'course',
    'cover', 'covered', 'covers', 'create', 'created', 'creates', 'critical',
    'currently', 'curve', 'curves',
    'dark', 'deal', 'dealing', 'decide', 'decrease', 'decreased', 'decreases',
    'decreasing', 'dedicated', 'deep', 'default', 'define', 'defined', 'defines',
    'demonstrate', 'demonstrated', 'depends', 'describe', 'described', 'describes',
    'describing', 'description', 'design', 'designed', 'desired', 'detail',
    'detailed', 'details', 'detect', 'detected', 'detection', 'determine',
    'determined', 'develop', 'developed', 'developing', 'development',
    'diagram', 'did', 'difference', 'differences', 'different', 'difficult',
    'directly', 'direction', 'disappear', 'disappears', 'display', 'displayed',
    'displays', 'does', 'doing', 'done', 'double', 'down', 'draw', 'drawing',
    'driven', 'drives', 'drop', 'drops', 'dual', 'due', 'during', 'duty',
    'each', 'earlier', 'easily', 'easy', 'edge', 'effect', 'effects', 'either',
    'element', 'elements', 'else', 'employ', 'employed', 'enable', 'enabled',
    'enables', 'encounter', 'encountered', 'end', 'ends', 'enough', 'ensure',
    'entire', 'equal', 'equals', 'equivalent', 'error', 'especially', 'essential',
    'essentially', 'establish', 'established', 'even', 'event', 'events', 'every',
    'evident', 'exactly', 'exam', 'examine', 'example', 'examples', 'except',
    'excess', 'excessive', 'exchange', 'exercise', 'exercises', 'exist', 'exists',
    'expect', 'expected', 'experience', 'explain', 'explained', 'explanation',
    'explore', 'expressed', 'extend', 'extended', 'extends', 'extensive',
    'external', 'extra', 'extreme', 'extremely',
    'face', 'facing', 'fact', 'factor', 'factors', 'fail', 'failed', 'failure',
    'failures', 'fairly', 'fall', 'falls', 'familiar', 'family', 'fast', 'faster',
    'feature', 'features', 'feed', 'feel', 'field', 'figure', 'final', 'finally',
    'find', 'fine', 'first', 'five', 'flow', 'flows', 'focus', 'follow',
    'followed', 'following', 'follows', 'force', 'forces', 'form', 'former',
    'forward', 'found', 'four', 'free', 'from', 'front', 'full', 'fully',
    'function', 'functions', 'further', 'furthermore',
    'gain', 'gains', 'gave', 'general', 'generally', 'generated', 'generating',
    'get', 'gets', 'getting', 'give', 'given', 'gives', 'giving', 'global',
    'goes', 'going', 'good', 'got', 'gradually', 'graph', 'great', 'greater',
    'greatly', 'green', 'grey', 'group', 'groups', 'grow', 'growing', 'grown',
    'grows', 'growth', 'guaranteed',
    'had', 'half', 'hand', 'handle', 'handled', 'handling', 'happen', 'happens',
    'hard', 'has', 'have', 'having', 'help', 'helps', 'hence', 'her', 'here',
    'high', 'higher', 'highest', 'highly', 'him', 'his', 'hold', 'holding',
    'holds', 'horizontal', 'how', 'however', 'huge',
    'idea', 'identify', 'immediately', 'impact', 'implement', 'implemented',
    'implements', 'importance', 'important', 'impose', 'imposed', 'imposes',
    'impossible', 'improve', 'include', 'included', 'includes', 'including',
    'incorporate', 'increase', 'increased', 'increases', 'increasing',
    'increasingly', 'indeed', 'independent', 'indicate', 'indicated', 'indicates',
    'indicating', 'indication', 'indicator', 'indicators', 'individual',
    'influence', 'influenced', 'influences', 'information', 'initial', 'initially',
    'inner', 'input', 'inputs', 'inside', 'installed', 'instance', 'instead',
    'intended', 'interest', 'interesting', 'internal', 'into', 'introduce',
    'introduced', 'introduces', 'introduction', 'involve', 'involved', 'involves',
    'involving', 'issue', 'issues', 'item', 'items', 'its', 'itself',
    'just', 'keep', 'keeping', 'keeps', 'kept', 'key', 'kind', 'know',
    'knowledge', 'known', 'knows',
    'label', 'labeled', 'labels', 'lack', 'large', 'larger', 'largest', 'last',
    'late', 'later', 'latter', 'lead', 'leading', 'leads', 'learn', 'learned',
    'learning', 'least', 'leave', 'leaves', 'led', 'left', 'less', 'let',
    'level', 'levels', 'light', 'like', 'likely', 'limit', 'limited', 'limits',
    'line', 'lines', 'link', 'linked', 'list', 'load', 'located', 'location',
    'long', 'longer', 'look', 'looking', 'looks', 'lose', 'loss', 'losses',
    'lost', 'low', 'lower', 'lowest',
    'made', 'main', 'mainly', 'maintain', 'maintained', 'maintaining', 'maintains',
    'major', 'make', 'makes', 'making', 'manage', 'managed', 'management',
    'manner', 'manual', 'manually', 'many', 'mark', 'marked', 'marks', 'matter',
    'maximum', 'may', 'mean', 'meaning', 'means', 'meant', 'measure', 'measured',
    'measures', 'measuring', 'mechanism', 'meet', 'meets', 'mention', 'mentioned',
    'method', 'might', 'mind', 'minimum', 'minor', 'minute', 'minutes', 'mode',
    'model', 'models', 'modern', 'modified', 'moment', 'monitor', 'monitoring',
    'more', 'moreover', 'most', 'mostly', 'motion', 'move', 'moved', 'movement',
    'moves', 'moving', 'much', 'multiple', 'must',
    'name', 'named', 'names', 'natural', 'naturally', 'nature', 'near', 'nearly',
    'necessary', 'need', 'needed', 'needs', 'neither', 'network', 'never', 'new',
    'next', 'nil', 'nor', 'normal', 'normally', 'not', 'note', 'noted', 'nothing',
    'notice', 'noticed', 'noting', 'now', 'number', 'numbers', 'numerous',
    'object', 'objective', 'objects', 'observe', 'observed', 'observing', 'obtain',
    'obtained', 'obvious', 'obviously', 'occur', 'occurred', 'occurring', 'occurs',
    'off', 'offer', 'offered', 'offers', 'often', 'old', 'once', 'one', 'ones',
    'only', 'onto', 'open', 'opened', 'opening', 'opens', 'operate', 'operated',
    'operates', 'operating', 'operation', 'operational', 'operations', 'operator',
    'option', 'options', 'order', 'ordered', 'orders', 'original', 'originally',
    'other', 'others', 'otherwise', 'our', 'out', 'outer', 'output', 'outputs',
    'outside', 'over', 'overall', 'own',
    'page', 'pair', 'panel', 'part', 'particular', 'particularly', 'parts',
    'pass', 'passed', 'passes', 'past', 'path', 'peak', 'per', 'percent',
    'percentage', 'perfect', 'perfectly', 'perform', 'performed', 'performing',
    'period', 'permit', 'permits', 'permitted', 'person', 'place', 'placed',
    'places', 'plan', 'play', 'plays', 'please', 'plus', 'point', 'pointed',
    'points', 'position', 'positions', 'positive', 'possible', 'possibly',
    'potential', 'power', 'practical', 'practically', 'practice', 'precisely',
    'present', 'presented', 'presents', 'press', 'pressed', 'pressing', 'prevent',
    'prevented', 'preventing', 'prevents', 'previous', 'previously', 'primarily',
    'primary', 'principle', 'principles', 'prior', 'problem', 'problems',
    'procedure', 'procedures', 'proceed', 'proceeds', 'process', 'processes',
    'produce', 'produced', 'produces', 'producing', 'product', 'production',
    'program', 'progress', 'project', 'proper', 'properly', 'property',
    'proportion', 'protect', 'protected', 'protecting', 'protection', 'provide',
    'provided', 'provides', 'providing', 'pull', 'purpose', 'purposes', 'push',
    'put', 'puts', 'putting',
    'quality', 'quantity', 'question', 'questions', 'quickly', 'quite',
    'raise', 'raised', 'raises', 'range', 'ranges', 'rapid', 'rapidly', 'rate',
    'rather', 'reach', 'reached', 'reaches', 'reaching', 'read', 'reading',
    'ready', 'real', 'reality', 'realize', 'really', 'reason', 'reasonable',
    'reasons', 'receive', 'received', 'receives', 'receiving', 'recent',
    'recently', 'recommend', 'recommended', 'record', 'recorded', 'records',
    'recover', 'recovery', 'red', 'reduce', 'reduced', 'reduces', 'reducing',
    'reduction', 'refer', 'reference', 'referred', 'refers', 'reflect',
    'reflected', 'regarding', 'region', 'regular', 'regularly', 'relate',
    'related', 'relates', 'relation', 'relationship', 'relative', 'relatively',
    'release', 'released', 'relevant', 'rely', 'remain', 'remaining', 'remains',
    'remember', 'remind', 'remote', 'remotely', 'remove', 'removed', 'removes',
    'repeat', 'repeated', 'replace', 'replaced', 'report', 'reported',
    'represent', 'represented', 'representing', 'represents', 'request',
    'requested', 'require', 'required', 'requires', 'requiring', 'respect',
    'respective', 'respond', 'responds', 'response', 'responsible', 'rest',
    'restore', 'restored', 'restriction', 'result', 'resulting', 'results',
    'return', 'returned', 'returning', 'returns', 'reveal', 'reveals', 'review',
    'right', 'rise', 'rises', 'rising', 'role', 'round', 'row', 'rows',
    'rule', 'rules', 'run', 'running', 'runs',
    'safe', 'safety', 'said', 'same', 'sample', 'satisfy', 'save', 'say',
    'says', 'scale', 'scenario', 'scene', 'screen', 'second', 'seconds',
    'section', 'sections', 'see', 'seeing', 'seek', 'seem', 'seems', 'seen',
    'select', 'selected', 'selection', 'send', 'sending', 'sends', 'sense',
    'sent', 'separate', 'separated', 'separately', 'sequence', 'series',
    'serious', 'serve', 'served', 'serves', 'service', 'set', 'sets', 'setting',
    'settings', 'setup', 'several', 'shall', 'shape', 'share', 'shared',
    'she', 'short', 'shorter', 'shortly', 'should', 'show', 'showed', 'showing',
    'shown', 'shows', 'shut', 'shutdown', 'side', 'sides', 'sign', 'signal',
    'signals', 'significant', 'significantly', 'similar', 'similarly', 'simple',
    'simply', 'simulate', 'simulated', 'simulates', 'simulating', 'simulation',
    'simulator', 'simulators', 'simultaneously', 'since', 'single', 'situation',
    'situations', 'six', 'slight', 'slightly', 'slow', 'slower', 'slowly',
    'small', 'smaller', 'smooth', 'smoothly', 'so', 'software', 'solely',
    'solution', 'solutions', 'solve', 'some', 'something', 'sometimes', 'soon',
    'sort', 'source', 'sources', 'space', 'special', 'specific', 'specifically',
    'specified', 'speed', 'speeds', 'stage', 'stages', 'standard', 'standards',
    'standing', 'stands', 'start', 'started', 'starting', 'starts', 'state',
    'stated', 'states', 'status', 'stay', 'stays', 'steady', 'step', 'steps',
    'still', 'stop', 'stopped', 'stopping', 'stops', 'store', 'stored', 'stores',
    'strong', 'stronger', 'strongly', 'structure', 'structures', 'student',
    'students', 'studied', 'studies', 'study', 'sub', 'subject', 'subsequent',
    'subsequently', 'substantial', 'substantially', 'success', 'successful',
    'successfully', 'such', 'sudden', 'suddenly', 'sufficient', 'sufficiently',
    'suggest', 'suggested', 'suggests', 'suitable', 'summary', 'supply',
    'supplied', 'support', 'supported', 'supports', 'suppose', 'sure',
    'surface', 'switch', 'switched', 'switches', 'switching', 'symbol',
    'system', 'systems',
    'table', 'tables', 'take', 'taken', 'takes', 'taking', 'talk', 'target',
    'teach', 'teaching', 'technology', 'tell', 'tells', 'temporarily',
    'temporary', 'ten', 'tend', 'tends', 'term', 'terms', 'test', 'testing',
    'tests', 'text', 'than', 'that', 'the', 'their', 'them', 'themselves',
    'then', 'theory', 'there', 'therefore', 'these', 'they', 'thing', 'things',
    'think', 'thinking', 'third', 'this', 'those', 'though', 'thought', 'three',
    'through', 'throughout', 'thus', 'time', 'times', 'tiny', 'title', 'today',
    'together', 'told', 'too', 'took', 'tool', 'tools', 'top', 'topic', 'topics',
    'total', 'totally', 'toward', 'towards', 'track', 'traditional',
    'traditionally', 'transfer', 'transferred', 'transfers', 'tries', 'true',
    'try', 'trying', 'turn', 'turned', 'turning', 'turns', 'twice', 'two',
    'type', 'types', 'typical', 'typically',
    'under', 'understand', 'understanding', 'understood', 'unit', 'units',
    'unless', 'unlike', 'until', 'up', 'upon', 'upper', 'us', 'use', 'used',
    'useful', 'user', 'users', 'uses', 'using', 'usual', 'usually',
    'valid', 'value', 'values', 'variable', 'variables', 'variation', 'various',
    'vary', 'varies', 'varying', 'version', 'vertical', 'very', 'via', 'view',
    'visible', 'visual',
    'wait', 'waiting', 'want', 'wanted', 'wants', 'was', 'watch', 'water', 'way',
    'ways', 'well', 'went', 'were', 'what', 'whatever', 'whatsoever', 'when',
    'whenever', 'where', 'whereas', 'whether', 'which', 'while', 'white', 'whole',
    'whose', 'why', 'wide', 'widely', 'wider', 'will', 'with', 'within',
    'without', 'word', 'words', 'work', 'worked', 'working', 'works', 'world',
    'worse', 'worst', 'worth', 'would', 'write', 'written', 'wrong',
    'year', 'years', 'yellow', 'yes', 'yet', 'you', 'young', 'your', 'yourself',
    'zero', 'zone', 'zones',
    # --- Additional common words (seen in tutorial output) ---
    'abnormal', 'absolute', 'acceptable', 'access', 'accessible', 'achieve',
    'achieved', 'acknowledge', 'acknowledged', 'acknowledgment', 'acting',
    'activate', 'activated', 'activates', 'activation', 'actively', 'adapt',
    'adapting', 'adequate', 'adjust', 'adjusting', 'adjustment', 'adjustments',
    'adjusts', 'advanced', 'advantage', 'advantages', 'affects', 'aggressive',
    'aggressively', 'aligned', 'alignment', 'alternative', 'ambient', 'analog',
    'annual', 'annually', 'approaching', 'appropriate', 'approx', 'approximately',
    'assembly', 'associated', 'assume', 'assuming', 'attached', 'attention',
    'authors', 'automatic', 'automatically', 'average', 'avoid', 'background',
    'backup', 'balanced', 'barely', 'becoming', 'behind', 'benefit', 'benefits',
    'bibliography', 'bigger', 'block', 'blocks', 'bottom', 'brief', 'brilliant',
    'bringing', 'buttons', 'calculate', 'calculates', 'calculation', 'calibration',
    'capabilities', 'capacity', 'careful', 'carefully', 'centre', 'challenge',
    'chapter', 'characteristic', 'characteristics', 'circulated', 'clever',
    'clockwise', 'column', 'columns', 'combined', 'combining', 'comment',
    'comparison', 'completed', 'complexity', 'compromise', 'computing',
    'connected', 'connecting', 'connection', 'connections', 'connects',
    'consideration', 'considerations', 'constantly', 'consumed', 'consuming',
    'controlled', 'controller', 'controlling', 'conventional', 'cooling',
    'correctly', 'counterclockwise', 'cycle', 'damage', 'dangerous', 'dates',
    'decision', 'dedicated', 'depending', 'description', 'desired', 'device',
    'devices', 'digital', 'directly', 'disconnected', 'display', 'displayed',
    'displays', 'document', 'documented', 'doesn', 'drawing', 'duration',
    'easily', 'edge', 'effective', 'effectively', 'efficiency', 'efficient',
    'equipment', 'equivalent', 'error', 'errors', 'especially', 'essential',
    'essentially', 'evident', 'evolution', 'exactly', 'excellent', 'executing',
    'execution', 'experiment', 'experiments', 'explanation', 'express',
    'expressed', 'expression', 'extensive', 'external', 'extra', 'extraction',
    'extreme', 'extremely',
    'fairly', 'familiar', 'faster', 'figures', 'fixed', 'forcing', 'format',
    'format', 'forms', 'formula', 'front', 'furthermore', 'global', 'gradually',
    'gradual', 'guaranteed', 'handle', 'handling', 'happen', 'happens', 'hence',
    'hence', 'identify', 'identified', 'implementing', 'implies',
    'indicating', 'indication', 'indicators', 'indicator', 'individual',
    'influence', 'inform', 'informed', 'initial', 'initially', 'inner',
    'installed', 'instance', 'instead', 'intent', 'intended', 'intentionally',
    'interest', 'interesting', 'intermediate', 'intro', 'involving', 'itself',
    'keeps', 'keeping', 'knowledge', 'largest', 'leading', 'learn', 'learned',
    'learning', 'legend', 'likewise', 'linked', 'loads', 'located', 'location',
    'manual', 'manually', 'marks', 'matter', 'mature', 'mechanism',
    'medium', 'meters', 'modify', 'modifier', 'moment', 'monitor',
    'monitoring', 'moreover', 'multiple', 'negative', 'nominal', 'normally',
    'notice', 'noticed', 'noting', 'number', 'numbers', 'objective', 'objects',
    'observe', 'observed', 'obtain', 'obtained', 'occur', 'occurring',
    'occurs', 'opening', 'operate', 'operated', 'operating', 'operation',
    'operations', 'operator', 'opposite', 'optimal', 'option', 'options',
    'organization', 'original', 'originally', 'otherwise', 'overall',
    'partially', 'particular', 'particularly', 'pattern', 'patterns',
    'percent', 'percentage', 'perfect', 'perfectly', 'perform', 'performed',
    'performing', 'period', 'permit', 'permitted', 'perspective', 'placed',
    'places', 'point', 'pointed', 'points', 'position', 'positions',
    'positive', 'possible', 'possibly', 'potential', 'practical', 'precisely',
    'present', 'presented', 'presents', 'press', 'pressed', 'pressing',
    'prevent', 'prevented', 'preventing', 'prevents', 'previous', 'previously',
    'primarily', 'primary', 'principle', 'principles', 'prior', 'problem',
    'problems', 'procedure', 'procedures', 'proceed', 'process', 'processes',
    'produce', 'produced', 'producing', 'product', 'production', 'program',
    'progress', 'project', 'proper', 'properly', 'property', 'proportion',
    'protect', 'protected', 'protection', 'provide', 'provided', 'provides',
    'providing', 'purpose', 'purposes', 'quality', 'quantity', 'question',
    'questions', 'quickly', 'quite', 'range', 'ranges', 'rapid', 'rapidly',
    'reading', 'ready', 'real', 'reality', 'realize', 'really', 'reason',
    'reasonable', 'reasons', 'receive', 'received', 'record', 'recorded',
    'recover', 'recovery', 'reduce', 'reduced', 'reduces', 'reducing',
    'reduction', 'reference', 'referenced', 'referred', 'refers', 'reflect',
    'reflected', 'regarding', 'region', 'regular', 'regularly', 'relate',
    'related', 'relation', 'relationship', 'relative', 'relatively', 'release',
    'released', 'relevant', 'remain', 'remaining', 'remains', 'remember',
    'replace', 'replaced', 'report', 'reported', 'represent', 'represented',
    'representing', 'represents', 'required', 'requires', 'requiring',
    'reserved', 'respect', 'respective', 'respond', 'responds', 'response',
    'responsible', 'result', 'resulting', 'results', 'return', 'returned',
    'returning', 'returns', 'reveal', 'reveals', 'review', 'rights',
    'round', 'running',
    # --- Spanish function words ---
    'abajo', 'acaba', 'acerca', 'acuerdo', 'además', 'adicionalmente',
    'ahora', 'algo', 'algunas', 'alguno', 'algunos', 'algún', 'alta', 'alto',
    'alrededor', 'ambas', 'ambos', 'anterior', 'anteriores', 'antes', 'aquí',
    'arriba', 'asegúrese', 'asociado', 'asociada', 'asociados', 'así', 'aunque',
    'bajo', 'bastante', 'bien', 'buena', 'bueno', 'cada', 'caso', 'casos',
    'casi', 'cierto', 'como', 'con', 'conjunto', 'consiste', 'correspondiente',
    'correspondientes', 'corresponde', 'corresponden', 'correspondant', 'cual',
    'cualquier', 'cuanto', 'cuando', 'cuenta', 'dado', 'datos', 'debe',
    'debajo', 'debido', 'decir', 'del', 'demás', 'dentro', 'depende',
    'descripción', 'desde', 'después', 'determinado', 'diferencia', 'diferentes',
    'directamente', 'dispone', 'donde', 'durante', 'efecto', 'ejemplo', 'ella',
    'ellas', 'ellos', 'embargo', 'encima', 'entonces', 'entre', 'esa', 'esas',
    'ese', 'eso', 'esos', 'esta', 'estado', 'estados', 'están', 'estar',
    'estas', 'este', 'esto', 'estos', 'eventos', 'evolución', 'existe',
    'existen', 'figura', 'forma', 'fue', 'fueron', 'funcionamiento', 'función',
    'funciones', 'generalmente', 'gran', 'grande', 'gráfico', 'gráficos',
    'hacia', 'hasta', 'hay', 'hacer', 'hecho', 'importante', 'implica',
    'indica', 'indicador', 'indicadores', 'inferior', 'inicia', 'introducción',
    'izquierda', 'lado', 'las', 'les', 'leva', 'llega', 'lleva', 'llegar',
    'lógicamente', 'los', 'luego', 'límite', 'manera', 'mantiene', 'mas',
    'mayor', 'máximo', 'mediante', 'mejor', 'menor', 'menos', 'mientras',
    'mismo', 'misma', 'mismos', 'modo', 'momento', 'mucho', 'muestra',
    'muestran', 'muy', 'más', 'máquina', 'máquinas', 'necesario', 'nombre',
    'nos', 'nueva', 'nuevo', 'nuevos', 'numero', 'número', 'objetivo',
    'observar', 'obra', 'ocurre', 'operación', 'operaciones', 'operador',
    'orden', 'otra', 'otras', 'otro', 'otros', 'para', 'parte', 'pero', 'poco',
    'poder', 'podemos', 'podría', 'poner', 'por', 'posible', 'posibles',
    'posición', 'presenta', 'presentan', 'primer', 'primera', 'primero',
    'principal', 'procedimiento', 'proceso', 'propio', 'propia', 'puede',
    'pueden', 'pues', 'punto', 'pequeño', 'permite', 'permiten', 'que',
    'realiza', 'realizar', 'resulta', 'sea', 'según', 'ser', 'sido', 'siendo',
    'siempre', 'sigue', 'siguiente', 'sin', 'sino', 'sólo', 'solo', 'sobre',
    'son', 'suele', 'sus', 'también', 'tanto', 'tiene', 'tienen', 'tipo',
    'tipos', 'toda', 'todas', 'todavía', 'todo', 'todos', 'tres', 'trata',
    'través', 'una', 'unas', 'uno', 'unos', 'utiliza', 'utilizar', 'valor',
    'valores', 'vamos', 'varias', 'varios', 'vemos', 'viene',
    # --- French function words ---
    'afin', 'aide', 'ainsi', 'alors', 'après', 'aura', 'aussi', 'autour',
    'autre', 'autres', 'auxquels', 'aux', 'avant', 'avec', 'avoir', 'basée',
    'bien', 'bord', 'bref', 'celle', 'celui', 'cependant', 'certaine',
    'certaines', 'certains', 'cette', 'chacun', 'chacune', 'chaque', 'chez',
    'comme', 'comment', 'composants', 'comprend', 'compris', 'compte',
    'connu', 'connue', 'conséquent', 'conséquence', 'correspondant', 'côté',
    'dans', 'des', 'dessous', 'dessus', 'deux', 'différents', 'différentes',
    'doit', 'doivent', 'donc', 'dont', 'données', 'droite', 'définir',
    'dépasse', 'dépend', 'effet', 'elle', 'elles', 'encore', 'ensemble',
    'entre', 'entrée', 'est', 'exemple', 'existe', 'existen', 'façon',
    'faire', 'fait', 'faut', 'fonction', 'fonctionnement', 'forme', 'gauche',
    'généralement', 'jusqu', 'laquelle', 'leur', 'leurs', 'lorsque', 'mais',
    'manière', 'mesure', 'montre', 'même', 'mêmes', 'nombre', 'nous',
    'opération', 'outil', 'outre', 'par', 'parce', 'part', 'partie', 'partir',
    'pas', 'pendant', 'permet', 'petit', 'petite', 'peu', 'peut', 'peuvent',
    'plusieurs', 'plus', 'pour', 'pouvez', 'premier', 'principale', 'près',
    'processus', 'puis', 'puisque', 'quand', 'quel', 'quelque', 'quelques',
    'qui', 'quoi', 'sans', 'selon', 'sera', 'seront', 'seulement', 'soit',
    'sont', 'sous', 'souvent', 'suite', 'sur', 'tant', 'telle', 'tels', 'tel',
    'temps', 'toujours', 'tous', 'tout', 'toute', 'toutes', 'trouve', 'très',
    'trop', 'trois', 'une', 'vers', 'veut', 'voici', 'voir', 'vous',
    # --- HTML / CSS / JS artifacts ---
    'amp', 'class', 'content', 'data', 'false', 'font', 'head', 'height',
    'href', 'html', 'http', 'https', 'icon', 'image', 'left', 'link', 'meta',
    'name', 'none', 'null', 'right', 'script', 'size', 'span', 'style', 'text',
    'title', 'true', 'type', 'width', 'align', 'border', 'cell', 'color',
    'margin', 'padding', 'table', 'pixel', 'solid', 'center', 'auto',
}


def parse_owl(hndsd_path):
    """
    Parse the oWl array from an hndsd.js file.
    Returns dict: { word: num_topics_it_appears_in }
    
    Format: var oWl=['word1',[[topicIdx,count],[topicIdx,count]],'word2',[[...]], ...]
    """
    with open(hndsd_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract the oWl array content
    m = re.search(r'var\s+oWl\s*=\s*\[(.*)\];', content, re.DOTALL)
    if not m:
        print(f"  WARNING: No oWl found in {hndsd_path}")
        return {}
    
    owl_str = m.group(1)
    
    # Parse word entries: 'word',[[idx,cnt],[idx,cnt],...]
    # Each word is followed by its topic-score array
    word_topics = {}
    # Find all quoted words followed by their arrays
    pattern = r"'([^']+)'\s*,\s*\[(\[[^\]]*\](?:\s*,\s*\[[^\]]*\])*)\]"
    for match in re.finditer(pattern, owl_str):
        word = match.group(1)
        scores_str = match.group(2)
        # Count number of [idx,cnt] pairs = number of topics
        num_topics = len(re.findall(r'\[', scores_str))
        word_topics[word] = num_topics
    
    return word_topics


def extract_keywords_from_hndsd(hndsd_path, min_topics=MIN_TOPICS, min_len=MIN_WORD_LEN):
    """Extract keywords meeting the frequency threshold."""
    word_topics = parse_owl(hndsd_path)
    
    keywords = []
    for word, count in word_topics.items():
        w = word.lower()
        if (count >= min_topics
                and len(w) >= min_len
                and ALPHA_ONLY.match(w)
                and w not in STOP_WORDS):
            keywords.append(w)
    
    return sorted(set(keywords))


def collect_all_keywords():
    """Scan all configured hndsd.js files and group extracted keywords by section."""
    section_words = defaultdict(set)
    
    for rel_path, section in PATH_TO_SECTION.items():
        hndsd_path = os.path.join(LAUNCHER_DIR, rel_path.replace('/', os.sep), 'js', 'hndsd.js')
        
        if not os.path.exists(hndsd_path):
            print(f"  SKIP: {hndsd_path} (not found)")
            continue
        
        words = extract_keywords_from_hndsd(hndsd_path)
        lang = rel_path.split('/')[1]  # en, es, fr
        print(f"  {rel_path}: {len(words)} keywords (lang={lang}, section={section})")
        
        section_words[section].update(words)
    
    return section_words


def build_search_keywords_json(section_words):
    """Build the complete JSON array: manual entries + extracted entries."""
    # Collect all words already in manual entries (to avoid duplicates)
    manual_words = set()
    for entry in MANUAL_KEYWORDS:
        for kw in entry["keywords"]:
            manual_words.add(kw.lower())
    
    result = list(MANUAL_KEYWORDS)  # start with manual entries
    
    # Add extracted keywords per section
    for section in sorted(section_words.keys()):
        words = sorted(section_words[section])
        # Remove words already covered by manual entries for this section
        new_words = [w for w in words if w not in manual_words]
        
        if not new_words:
            continue
        
        # Split into chunks of ~40 keywords per entry for readability
        CHUNK_SIZE = 40
        for i in range(0, len(new_words), CHUNK_SIZE):
            chunk = new_words[i:i+CHUNK_SIZE]
            result.append({
                "keywords": chunk,
                "section": section
            })
    
    return result


def format_json_block(entries):
    """Format the JSON as indented block for embedding in HTML."""
    lines = ["      ["]
    for i, entry in enumerate(entries):
        comma = "," if i < len(entries) - 1 else ""
        kw_str = json.dumps(entry["keywords"], ensure_ascii=False)
        lines.append(f'        {{ "keywords": {kw_str}, "section": "{entry["section"]}" }}{comma}')
    lines.append("      ]")
    return "\n".join(lines)


def update_index_html(new_json_block, dry_run=True):
    """Replace the searchKeywords script block in index.html."""
    with open(INDEX_HTML, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Match the entire <script id="searchKeywords"> ... </script> block
    pattern = r'(<script id="searchKeywords" type="application/json">)\s*\[.*?\]\s*(</script>)'
    replacement = f'\\1\n{new_json_block}\n    \\2'
    
    new_content, count = re.subn(pattern, replacement, content, flags=re.DOTALL)
    
    if count == 0:
        print("ERROR: Could not find searchKeywords block in index.html!")
        return False
    
    if dry_run:
        print(f"\n--- DRY RUN: Would update {INDEX_HTML} ---")
        # Show just the new block
        for line in new_json_block.split('\n')[:20]:
            print(f"  {line}")
        if new_json_block.count('\n') > 20:
            print(f"  ... ({new_json_block.count(chr(10)) - 20} more lines)")
        return True
    else:
        with open(INDEX_HTML, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"\nUpdated {INDEX_HTML}")
        return True


def main():
    apply = '--apply' in sys.argv
    
    print("=" * 60)
    print("Tutorial Keywords Extractor for Launcher")
    print(f"Min topics: {MIN_TOPICS} | Min word length: {MIN_WORD_LEN}")
    print(f"Mode: {'APPLY' if apply else 'DRY-RUN (use --apply to write)'}")
    print("=" * 60)
    
    print("\nScanning hndsd.js files...")
    section_words = collect_all_keywords()
    
    print(f"\nKeywords per section:")
    total = 0
    for section in sorted(section_words.keys()):
        count = len(section_words[section])
        total += count
        print(f"  {section}: {count} keywords")
    print(f"  TOTAL extracted: {total}")
    
    # Collect manual words count
    manual_count = sum(len(e["keywords"]) for e in MANUAL_KEYWORDS)
    print(f"  Manual (preserved): {manual_count}")
    
    entries = build_search_keywords_json(section_words)
    json_block = format_json_block(entries)
    
    # Count total unique keywords in final output
    all_kw = set()
    for e in entries:
        all_kw.update(e["keywords"])
    print(f"  Final unique keywords: {len(all_kw)}")
    
    # Show some sample extracted words per section
    print("\nSample extracted keywords:")
    for section in sorted(section_words.keys()):
        words = sorted(section_words[section])[:15]
        print(f"  {section}: {', '.join(words)}...")
    
    success = update_index_html(json_block, dry_run=not apply)
    
    if success and apply:
        print("\nDone! Search keywords updated in index.html.")
        print("To re-run after adding new tutorials:")
        print("  1. Add the new hndsd.js path to PATH_TO_SECTION in this script")
        print("  2. Run: python extract_tutorial_keywords.py --apply")
    elif success:
        print("\nDry run complete. Run with --apply to update index.html.")


if __name__ == '__main__':
    main()
