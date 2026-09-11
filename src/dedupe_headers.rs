//! Helper script to deduplicate directories of headers across wasi
//! targets/builds.
//!
//! Right now each target is built in isolation, e.g. `wasm32-wasip{1,2,3}` and
//! additionally each target has `libcxx` built with/without exceptions. This is
//! quite a lot of header files in this full matrix (e.g. 6 copies of libcxx
//! headers at least), but generally the files are all the same across all
//! these targets. Clang's sysroot logic looks first in target-specific
//! locations but then additionally consults more generic locations, and this
//! script massages the input into an outupt directory suitable to have the same
//! view according to clang.
//!
//! Specifically if the same header is present in every single target-specific
//! directory, then it's copied up to the target-agnostic sysroot. This is
//! done without symlinks to work well on Windows and means that the
//! target-specific directories are generally quite small compared to the full
//! complete list of directories.
//!
//! Note that special care is taken for the "eh" and "noeh" directories which
//! are the libcxx builds with/without exceptions. If those are encountered
//! then only files duplicated across both of them are lifted up.

use std::ffi::OsString;
use std::fs::{self, FileType};
use std::path::{Path, PathBuf};

macro_rules! debug {
    ($($arg:tt)*) => {
        if true {
            eprintln!($($arg)*);
        }
    };
}

fn main() {
    let mut args = std::env::args_os();
    args.next().unwrap(); // skip exe name
    let src = PathBuf::from(args.next().unwrap());
    let dst = PathBuf::from(args.next().unwrap());

    copy(
        &src,
        &mut src
            .read_dir()
            .unwrap()
            .map(|d| d.unwrap().path())
            .collect::<Vec<_>>(),
        &dst,
        &mut PathBuf::new(),
    );
}

/// Copies all of the contents of each of the source directories from `srcs` to
/// `dst`, deduplicating anything in common into `dst`.
///
/// The `src_root` option is used as a relative prefix for everything within
/// `srcs` when some directories may differ. The `dst` is built up during the
/// recursive traversal and is a relative destination from `dst_root`.
fn copy(src_root: &Path, srcs: &mut Vec<PathBuf>, dst_root: &Path, dst: &mut PathBuf) {
    let mut src_entries = srcs
        .iter()
        .map(|s| {
            let mut entries = s
                .read_dir()
                .unwrap()
                .map(|e| {
                    let e = e.unwrap();
                    (e.file_name(), e.file_type().unwrap())
                })
                .collect::<Vec<_>>();
            entries.sort_by_key(|(name, _)| name.clone());
            (entries.into_iter().peekable(), s.clone())
        })
        .collect::<Vec<_>>();
    let ((first, src0), rest) = src_entries.split_first_mut().unwrap();

    while let Some(pair @ (name, ft)) = first.peek() {
        // Bring all iterators up to `name`
        for (other, src) in rest.iter_mut() {
            while let Some((e, ft)) = other.next_if(|(e, _)| e < name) {
                rel_cp_r(src_root, src, ft, dst_root, &e);
            }
        }

        // Test if all directories have either a directory for `name` or all
        // have a file for `name`.
        let src = src0.join(name);
        let contents = if ft.is_dir() {
            None
        } else {
            assert!(ft.is_file());
            Some(fs::read(&src).unwrap())
        };
        let all_same = rest.iter_mut().all(|(other, other_src)| {
            if other.peek() != Some(pair) {
                return false;
            }
            match &contents {
                Some(src0) => src0 == &fs::read(other_src.join(name)).unwrap(),
                None => true,
            }
        });

        // If everything is the same then this file or directory can be lifted
        // up without its target prefix, otherwise copy this file for the
        // `first` iterator and continue on.
        if all_same {
            if ft.is_dir() {
                if name != "eh" {
                    for src in srcs.iter_mut() {
                        src.push(name);
                    }
                    if name == "noeh" {
                        for mut src in srcs.clone() {
                            src.pop();
                            src.push("eh");
                            srcs.push(src);
                        }
                    } else {
                        fs::create_dir_all(&dst_root.join(&dst).join(name)).unwrap();
                        dst.push(name);
                    }
                    copy(src_root, srcs, dst_root, dst);
                    if name == "noeh" {
                        srcs.truncate(srcs.len() / 2);
                    } else {
                        dst.pop();
                    }
                    for src in srcs.iter_mut() {
                        src.pop();
                    }
                }
            } else {
                let dst = dst_root.join(&dst).join(name);
                debug!("deduplicate: {dst:?}");
                fs::copy(&src, &dst).unwrap();
            }
            for (other, _src) in rest.iter_mut() {
                other.next();
            }
        } else {
            rel_cp_r(src_root, src0, *ft, dst_root, name);
        }

        first.next();
    }

    // Copy over everything remaining in all other directories
    for (other, src) in rest.iter_mut() {
        for (e, ft) in other {
            rel_cp_r(src_root, src, ft, dst_root, &e);
        }
    }
}

fn rel_cp_r(src_root: &Path, src: &Path, ft: FileType, dst: &Path, name: &OsString) {
    let rel_path = src.strip_prefix(src_root).unwrap();
    let dst = dst.join(rel_path);
    fs::create_dir_all(&dst).unwrap();
    cp_r(&mut src.join(name), ft, &mut dst.join(name));
}

fn cp_r(src: &mut PathBuf, ft: FileType, dst: &mut PathBuf) {
    if ft.is_dir() {
        fs::create_dir_all(&dst).unwrap();
        for entry in src.read_dir().unwrap() {
            let entry = entry.unwrap();
            let name = entry.file_name();
            src.push(&name);
            dst.push(&name);
            cp_r(src, entry.file_type().unwrap(), dst);
            src.pop();
            dst.pop();
        }
    } else {
        debug!("unique: {dst:?}");
        fs::copy(src, &dst).unwrap();
    }
}
