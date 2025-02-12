from collections import deque

class TeraParser:
    def __init__(self):
        self.ast = []
        self.block_stack = []

    def parse(self, template):
        elements = self._split_elements(template)
        return self._build_ast(elements)

    def _split_elements(self, template):
        elements = []
        pos = 0
        in_raw = False

        while pos < len(template):
            if in_raw:
                end = template.find('{% endraw %}', pos)
                if end == -1:
                    elements.append(('text', template[pos:]))
                    break
                elements.append(('text', template[pos:end]))
                pos = end + 11  # Length of {% endraw %}
                in_raw = False
            else:
                next_var = template.find('{{', pos)
                next_stmt = template.find('{%', pos)
                next_comment = template.find('{#', pos)
                next_raw_start = template.find('{% raw %}', pos)

                # Find closest match
                matches = []
                if next_var != -1: matches.append(('var', next_var))
                if next_stmt != -1: matches.append(('stmt', next_stmt))
                if next_comment != -1: matches.append(('comment', next_comment))
                if next_raw_start != -1: matches.append(('raw_start', next_raw_start))

                if not matches:
                    elements.append(('text', template[pos:]))
                    break

                # Get first occurrence
                first = min(matches, key=lambda x: x[1])
                type_, idx = first

                if idx > pos:
                    elements.append(('text', template[pos:idx]))

                if type_ == 'var':
                    end = template.find('}}', idx+2)
                    if end == -1:
                        content = template[idx+2:]
                        elements.append(('variable', content.strip()))
                        break
                    content = template[idx+2:end].strip()
                    elements.append(('variable', content))
                    pos = end + 2
                elif type_ == 'stmt':
                    end = template.find('%}', idx+2)
                    if end == -1:
                        content = template[idx+2:]
                        elements.append(('statement', content.strip()))
                        break
                    content = template[idx+2:end].strip()
                    elements.append(('statement', content))
                    pos = end + 2
                elif type_ == 'comment':
                    end = template.find('#}', idx+2)
                    if end == -1:
                        content = template[idx+2:]
                        elements.append(('comment', content.strip()))
                        break
                    content = template[idx+2:end].strip()
                    elements.append(('comment', content))
                    pos = end + 2
                elif type_ == 'raw_start':
                    in_raw = True
                    pos = idx + 9  # Length of {% raw %}
        return elements

    def _build_ast(self, elements):
        ast = []
        current_block = None

        for el_type, content in elements:
            if el_type == 'statement':
                parts = content.split(maxsplit=1)
                keyword = parts[0]

                if keyword == 'set':
                    var, expr = self._parse_assignment(parts[1])
                    ast.append({'type': 'set', 'var': var, 'expr': expr})
                elif keyword == 'if':
                    condition = parts[1] if len(parts) > 1 else ''
                    node = {
                        'type': 'if',
                        'condition': condition,
                        'then': [],
                        'else': None
                    }
                    self.block_stack.append(ast)
                    ast.append(node)
                    ast = node['then']
                elif keyword == 'else':
                    if self.block_stack and isinstance(ast, list):
                        parent = self.block_stack[-1]
                        if parent and parent[-1]['type'] == 'if':
                            parent[-1]['else'] = []
                            ast = parent[-1]['else']
                elif keyword == 'endif':
                    if self.block_stack:
                        ast = self.block_stack.pop()
            elif el_type == 'variable':
                ast.append({'type': 'variable', 'expression': content})
            elif el_type == 'text' and content:
                ast.append({'type': 'text', 'content': content})

        return ast

    def _parse_assignment(self, stmt):
        parts = deque(stmt.split())
        var = parts.popleft() if parts else ''
        if parts and parts[0] == '=':
            parts.popleft()
        expr = ' '.join(parts)
        return var, expr

# Example usage
template = '''
{% set name = "Joe" %}
Hello, {% if name %}{{ name }}{% else %}World{% endif %}
'''

parser = TeraParser()
ast = parser.parse(template)

import pprint
pprint.pprint(ast)