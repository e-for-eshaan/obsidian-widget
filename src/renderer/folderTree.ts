export interface FolderTreeNode {
  path: string;
  name: string;
  children: FolderTreeNode[];
}

export function buildFolderTree(folders: string[]): FolderTreeNode[] {
  const nodes = new Map<string, FolderTreeNode>();
  const roots: FolderTreeNode[] = [];

  const sorted = [...folders].sort((left, right) => {
    if (left === '(root)') {
      return -1;
    }

    if (right === '(root)') {
      return 1;
    }

    return left.localeCompare(right);
  });

  for (const folderPath of sorted) {
    const node: FolderTreeNode = {
      path: folderPath,
      name: folderPath === '(root)' ? '(root)' : (folderPath.split('/').pop() ?? folderPath),
      children: [],
    };
    nodes.set(folderPath, node);

    if (folderPath === '(root)' || !folderPath.includes('/')) {
      roots.push(node);
      continue;
    }

    const parentPath = folderPath.slice(0, folderPath.lastIndexOf('/'));
    const parent = nodes.get(parentPath);
    if (parent) {
      parent.children.push(node);
    } else {
      roots.push(node);
    }
  }

  sortFolderTreeNodes(roots);
  return roots;
}

function sortFolderTreeNodes(nodes: FolderTreeNode[]): void {
  nodes.sort((left, right) => {
    if (left.path === '(root)') {
      return -1;
    }

    if (right.path === '(root)') {
      return 1;
    }

    return left.name.localeCompare(right.name);
  });

  for (const node of nodes) {
    sortFolderTreeNodes(node.children);
  }
}
