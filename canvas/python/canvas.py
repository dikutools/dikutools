#!/usr/bin/env python3

import sys
import urllib.parse
import urllib.request
import json


def format_json(d):
    return json.dumps(d, sort_keys=True, indent=2, ensure_ascii=False)

def _call_api(token, method, api_base, url_relative, **args):
    try:
        args = args['_arg_list']
    except KeyError:
        pass
    query_string = urllib.parse.urlencode(args, safe='[]@', doseq=True).encode('utf-8')
    url = api_base + url_relative
    headers = {
        'Authorization': 'Bearer ' + token
    }
    req = urllib.request.Request(url, data=query_string, method=method,
                                 headers=headers)
    with urllib.request.urlopen(req) as f:
        data = json.loads(f.read().decode('utf-8'))
    return data

class Course:
    def __init__(self, canvas, name):
        self.canvas = canvas
        self._lookup(name)

    def _lookup(self, name):
        ids = set()
        realnames = set()
        for course in self.canvas.courses():
            if name.lower() in course['name'].lower():
                ids.add(course['id'])
                realnames.add(course['name'])
        if len(ids) > 1:
            raise LookupError(
                "Multiple candidate courses \"{}\": \"{}\".".format(
                    name, "\", \"".join(list(realnames))))
        self.id = ids.pop()
        self.realname = realnames.pop()

class Canvas:
    def __init__(self,
                 api_base='https://absalon.ku.dk/api/v1/',
                 token=None):
        self.api_base = api_base

        if token is None:
            with open('token') as f:
                token = f.read().strip()
        self.token = token

    def get(self, url_relative, **args):
        return _call_api(self.token, 'GET', self.api_base, url_relative, **args)

    def post(self, url_relative, **args):
        return _call_api(self.token, 'POST', self.api_base, url_relative, **args)

    def put(self, url_relative, **args):
        return _call_api(self.token, 'PUT', self.api_base, url_relative, **args)

    def delete(self, url_relative, **args):
        return _call_api(self.token, 'DELETE', self.api_base, url_relative, **args)

    def courses(self):
        return self.get('courses')

    def course(self, course_id):
        return self.get('courses/{}'.format(course_id))

    def all_students(self, course_id):
        sections = self.get('courses/{}/sections'.format(course_id),
                            include='students')
        students = sections[0]['students'] # This only works if there's one
                                           # group for all students, like in the
                                           # typical "Hold 01" case.
        return students

    def course_student(self, course_id, user_id):
        user = self.get('courses/{}/users/{}'.format(course_id, user_id))
        return user

    def group_categories(self, course_id):
        return self.get('courses/{}/group_categories'.format(course_id))

    def create_group(self, group_category_id, name):
        return self.post('group_categories/{}/groups'.format(group_category_id),
                         name=name, join_level='invitation_only')

    def delete_all_assignment_groups(self, group_category_id):
        groups = self.get('group_categories/{}/groups'.format(group_category_id),
                          per_page=9000)
        group_ids = [g['id'] for g in groups]
        for gid in group_ids:
            self.delete('groups/{}'.format(gid))

    def add_group_members(self, group_id, members):
        args = {
            'members[]': members
        }
        return self.put('groups/{}'.format(group_id), **args)

    def list_assignments(self, course_id):
        return self.get('courses/{}/assignments'.format(course_id))

    def assignment(self, course_id, assignment_id):
        return self.get(
            'courses/{}/assignments/{}'.format(
                course_id, assignment_id))

    def submissions_download_url(self, course_id, assignment_id, dest):
        return self.assignment(
            course_id, assignment_id)['submissions_download_url']

def main(args):
    try:
        method = args[0].upper()
        url = args[1]
        args = args[2:]
        assert len(args) % 2 == 0
        args = [(args[i], args[i + 1]) for i in range(0, len(args), 2)]
    except IndexError:
        print('error: wrong arguments', file=sys.stderr)
        print('usage: canvas.py [GET|POST|PUT] URL [ARG_NAME ARG_VALUE]...',
              file=sys.stderr)
        return 1

    c = Canvas()
    call = {
        'GET': c.get,
        'POST': c.post,
        'PUT': c.put
    }[method]

    output = call(url, _arg_list=args)
    print(format_json(output))
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
