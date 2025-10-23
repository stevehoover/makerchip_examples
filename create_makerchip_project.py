#!/usr/bin/env python3
"""
Simple script to create a Makerchip project using the REST API.
Based on reverse-engineering the makerchip-app package.
"""

import requests
from urllib.parse import urljoin
import sys

class MakerchipAPI:
    """Simple wrapper for Makerchip REST API"""

    def __init__(self, server="https://makerchip.com/"):
        self.server = server
        self.session = requests.Session()
        self.proj_path = None

    def auth(self):
        """Authenticate with the public API"""
        try:
            resp = self.session.get(urljoin(self.server, 'auth/pub/'))
            resp.raise_for_status()
            print(f"✓ Authenticated with {self.server}")
            return True
        except Exception as e:
            print(f"✗ Authentication failed: {e}")
            return False

    def create_project(self, name, source, vcd=None):
        """Create a new public project

        Args:
            name: Project name (e.g., "my_design.tlv")
            source: Design source code (TL-Verilog or Verilog)
            vcd: Optional VCD waveform content

        Returns:
            Project path/ID if successful, None otherwise
        """
        data = {
            'name': name,
            'source': source
        }
        if vcd:
            data['vcd'] = vcd

        try:
            resp = self.session.post(
                urljoin(self.server, 'project/public/'),
                data=data
            )
            resp.raise_for_status()
            self.proj_path = resp.json()['path']
            print(f"✓ Project created: {self.proj_path}")
            return self.proj_path
        except Exception as e:
            print(f"✗ Project creation failed: {e}")
            return None

    def get_project_url(self):
        """Get the browser URL for the project"""
        if self.proj_path:
            return urljoin(self.server, f'sandbox/public/{self.proj_path}')
        return None

    def get_design_contents(self):
        """Fetch the current design source from the server"""
        if not self.proj_path:
            print("✗ No project created yet")
            return None

        try:
            resp = self.session.get(
                urljoin(self.server, f'project/public/{self.proj_path}/contents')
            )
            resp.raise_for_status()
            return resp.json()['value']
        except Exception as e:
            print(f"✗ Failed to get design contents: {e}")
            return None

    def delete_project(self):
        """Delete the project from the server"""
        if not self.proj_path:
            return

        try:
            self.session.get(
                urljoin(self.server, f'project/public/{self.proj_path}/delete')
            )
            print(f"✓ Project {self.proj_path} deleted")
            self.proj_path = None
        except Exception as e:
            print(f"✗ Failed to delete project: {e}")


def main():
    # Example TL-Verilog code
    example_code = """\
\\m5_TLV_version 1d: tl-x.org
\\m5
   use(m5-1.0)
\\SV
   m5_makerchip_module
\\TLV

   // Simple counter example
   $reset = *reset;

   $cnt[7:0] = $reset ? 0 : >>1$cnt + 1;

   *passed = $cnt == 8'd100;
   *failed = 1'b0;

\\SV
   endmodule
"""

    print("Makerchip REST API Demo")
    print("=" * 50)

    # Initialize API
    api = MakerchipAPI()

    # Authenticate
    if not api.auth():
        sys.exit(1)

    # Create project
    proj_id = api.create_project("counter_example.tlv", example_code)
    if not proj_id:
        sys.exit(1)

    # Get project URL
    url = api.get_project_url()
    print(f"\n🌐 Open in browser: {url}")
    print(f"\nProject ID: {proj_id}")

    # Optional: Fetch the design back
    print("\nFetching design contents...")
    contents = api.get_design_contents()
    if contents:
        print(f"✓ Retrieved {len(contents)} characters")

    # Clean up (optional - projects expire automatically)
    print("\nPress Enter to delete the project, or Ctrl+C to keep it...")
    try:
        input()
        api.delete_project()
    except KeyboardInterrupt:
        print("\n✓ Project kept on server")


if __name__ == "__main__":
    main()
