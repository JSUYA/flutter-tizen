// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "dali_application_abi.h"

#include <dlfcn.h>

#include <cstddef>
#include <cstdint>

#include "tizen_log.h"

namespace {

constexpr char kLibraryName[] = "libdali-application.so.1";

// Dali::Window (a Dali::BaseHandle): a single intrusive pointer.
struct DaliWindow {
  void *object = nullptr;

  DaliWindow() = default;
  DaliWindow(DaliWindow &&other) : object(other.object) {
    other.object = nullptr;
  }
  ~DaliWindow();
};

// Dali::Any: a single pointer to its value container.
// See <dali/public-api/object/any.h>.
struct DaliAny {
  void *container = nullptr;

  DaliAny() = default;
  DaliAny(DaliAny &&other) : container(other.container) {
    other.container = nullptr;
  }
  ~DaliAny();
};

// Dali::Any::AnyContainerImpl<T> for a pointer type T: the public
// AnyContainerBase members followed by the value. Any::GetType() returns a
// reference to the first member (mType) of the container, which locates the
// value in the same way as Any::Get<T>().
struct DaliAnyContainer {
  uint32_t type_id;       // TypeInfoId::mId
  const char *type_name;  // TypeInfoId::mName; nullptr if the Any is empty
  void *clone_func;
  void *delete_func;
  void *value;
};

static_assert(offsetof(DaliAnyContainer, value) == 4 * sizeof(void *),
              "Must match the layout of Dali::Any::AnyContainerImpl<T>.");

// Itanium C++ ABI: non-virtual member functions take |this| as their first
// argument. DaliWindow and DaliAny have non-trivial destructors like the
// classes they mirror, so the compiler returns them through the hidden result
// pointer exactly like the library does.
struct Symbols {
  void (*constructor)(DaliApplicationAbi *self, int argc, char **argv);
  void (*destructor)(DaliApplicationAbi *self);
  int (*run)(DaliApplicationAbi *self);
  void (*exit)(DaliApplicationAbi *self);
  DaliWindow (*get_default_window)(const DaliApplicationAbi *self);
  DaliAny (*window_get_native_handle)(const DaliWindow *self);
  void (*window_destructor)(DaliWindow *self);
  const DaliAnyContainer *(*any_get_type)(const DaliAny *self);
  void (*any_destructor)(DaliAny *self);
};

Symbols symbols = {};
bool loaded = false;

DaliWindow::~DaliWindow() {
  if (object) {
    symbols.window_destructor(this);
  }
}

DaliAny::~DaliAny() {
  if (container) {
    symbols.any_destructor(this);
  }
}

template <typename T>
bool Resolve(void *handle, const char *name, T *target) {
  *target = reinterpret_cast<T>(dlsym(handle, name));
  if (!*target) {
    TizenLog::Error("Could not find %s: %s", name, dlerror());
    return false;
  }
  return true;
}

}  // namespace

bool DaliApplicationAbi::Load() {
  if (loaded) {
    return true;
  }
  void *handle = dlopen(kLibraryName, RTLD_NOW | RTLD_GLOBAL);
  if (!handle) {
    TizenLog::Error("Could not load %s: %s", kLibraryName, dlerror());
    return false;
  }
  // tizen_appfw::DaliApplication
  loaded =
      Resolve(handle, "_ZN11tizen_appfw15DaliApplicationC1EiPPc",
              &symbols.constructor) &&
      Resolve(handle, "_ZN11tizen_appfw15DaliApplicationD1Ev",
              &symbols.destructor) &&
      Resolve(handle, "_ZN11tizen_appfw15DaliApplication3RunEv",
              &symbols.run) &&
      Resolve(handle, "_ZN11tizen_appfw15DaliApplication4ExitEv",
              &symbols.exit) &&
      Resolve(handle, "_ZNK11tizen_appfw15DaliApplication16GetDefaultWindowEv",
              &symbols.get_default_window) &&
      // Dali::Window from libdali2-adaptor.so.2, a dependency of the library.
      Resolve(handle, "_ZNK4Dali6Window15GetNativeHandleEv",
              &symbols.window_get_native_handle) &&
      Resolve(handle, "_ZN4Dali6WindowD1Ev", &symbols.window_destructor) &&
      // Dali::Any from libdali2-core.so.2.
      Resolve(handle, "_ZNK4Dali3Any7GetTypeEv", &symbols.any_get_type) &&
      Resolve(handle, "_ZN4Dali3AnyD1Ev", &symbols.any_destructor);
  return loaded;
}

DaliApplicationAbi::DaliApplicationAbi(int argc, char **argv) {
  // The constructor of the library initializes |impl_|. The derived class
  // restores its own vtable pointer afterwards, as for any base class.
  if (Load()) {
    symbols.constructor(this, argc, argv);
  }
}

DaliApplicationAbi::~DaliApplicationAbi() {
  if (impl_) {
    symbols.destructor(this);
  }
}

int DaliApplicationAbi::Run() {
  if (!impl_) {
    return -1;
  }
  return symbols.run(this);
}

void DaliApplicationAbi::Exit() {
  if (impl_) {
    symbols.exit(this);
  }
}

void *DaliApplicationAbi::GetDefaultWindowHandle() const {
  if (!impl_) {
    return nullptr;
  }
  DaliWindow window = symbols.get_default_window(this);
  if (!window.object) {
    TizenLog::Error("The default window of the DALi application is not ready.");
    return nullptr;
  }
  DaliAny handle = symbols.window_get_native_handle(&window);
  const DaliAnyContainer *container = symbols.any_get_type(&handle);
  if (!container->type_name || !container->value) {
    TizenLog::Error("The default window has no native window handle.");
    return nullptr;
  }
  TizenLog::Debug("Using the default window of the DALi application (%s).",
                  container->type_name);
  return container->value;
}
