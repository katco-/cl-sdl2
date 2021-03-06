(in-package :sdl2)

;;;; TODO
;;;; SDL_CreateWindowAndRenderer
;;;; SDL_GetRendererOutputSize

(defun make-renderer-info ()
  "Return an uninitialized SDL_RendererInfo structure."
  (sdl-collect (autowrap:alloc 'sdl2-ffi:sdl-renderer-info)))

(defmethod print-object ((rinfo sdl2-ffi:sdl-renderer-info) stream)
  (c-let ((rinfo sdl2-ffi:sdl-renderer-info :from rinfo))
    (print-unreadable-object (rinfo stream :type t :identity t)
      (format stream "name ~S flags ~A num-texture-formats ~A texture-formats TBD max-texture-width ~A max-texture-height ~A"
              (rinfo :name)
              (rinfo :flags)
              (rinfo :num-texture-formats)
              (rinfo :max-texture-width)
              (rinfo :max-texture-height)))))

(defun free-render-info (rinfo)
  "Specifically free the SDL_RendererInfo structure which will do the right
thing with respect to the garbage collector. This is not required, but
may make garbage collection performance better if used in tight
SDL_RendererInfo allocating loops."
  (foreign-free (ptr rinfo))
  (sdl-cancel-collect rinfo)
  (autowrap:invalidate rinfo))

;;;; And now the wrapping of the SDL2 calls

;; Create the keywords for the SDL_RendererFLags enum.
(autowrap:define-bitmask-from-enum
    (sdl-renderer-flags sdl2-ffi:sdl-renderer-flags))

;; Create the keywords for the SDL_TextureModulate enum.
(autowrap:define-bitmask-from-enum
    (sdl-texture-modulate sdl2-ffi:sdl-texture-modulate))

;; Create the keywords for the SDL_RendererFlip enum.
(autowrap:define-bitmask-from-enum
    (sdl-renderer-flip sdl2-ffi:sdl-renderer-flip))

(defun get-num-render-drivers ()
  "Return the number of 2D rendering drivers available for the current
display."
  (sdl-get-num-render-drivers))

(defun get-render-driver-info (index)
  "Allocate and return a new SDL_RendererInfo structure and fill it
with information relating to the specific 2D rendering driver
specified in the index."
  (let ((rinfo (make-renderer-info)))
    (check-rc (sdl-get-render-driver-info index rinfo))
    rinfo))

(defun create-window-and-renderer (width height flags)
  (c-let ((winptr :pointer :free t)
          (rendptr :pointer :free t))
    (check-rc (sdl-create-window-and-renderer
               width height
               (mask-apply 'sdl-window-flags flags)
               (winptr &) (rendptr &)))
    (let ((window
            (sdl-collect
             (sdl2-ffi::make-sdl-window :ptr winptr)
             (lambda (w) (sdl-destroy-window w))))
          (renderer
            (sdl-collect
             (sdl2-ffi::make-sdl-renderer :ptr rendptr)
             (lambda (r) (sdl-destroy-renderer r)))))
      (values window renderer))))

(defun create-renderer (window &optional index flags)
  "Create a 2D rendering context for a window."
  (sdl-collect
   (check-null (sdl-create-renderer
                window (or index -1)
                (mask-apply 'sdl-renderer-flags flags)))
   (lambda (r) (sdl-destroy-renderer r))))

(defun create-software-renderer (surface)
  "Create and return a 2D software rendering context for the surface."
  (check-null (sdl-create-software-renderer surface)))

(defun destroy-renderer (r)
  (sdl-cancel-collect r)
  (sdl-destroy-renderer r)
  (invalidate r))

(defmacro with-renderer ((renderer-sym window &key index flags) &body body)
  `(let ((,renderer-sym (sdl2:create-renderer ,window ,index ,flags)))
     (unwind-protect
          (progn ,@body)
       (sdl2:destroy-renderer ,renderer-sym))))

(defun get-renderer (window)
  "Return NIL if there is no renderer associated with the window, or otherwise
the SDL_Renderer structure."
  (let ((renderer (sdl-get-renderer window)))
    (if (null-pointer-p (autowrap:ptr renderer))
        nil
        renderer)))

(defun render-copy (renderer texture &key source-rect dest-rect)
  "Use this function to copy a portion of the texture to the current rendering target."
  (check-rc (sdl2-ffi.functions:sdl-render-copy renderer texture source-rect dest-rect)))

(defun render-present (renderer)
  "Use this function to update the screen with rendering performed."
  (sdl2-ffi.functions:sdl-render-present renderer))

(defun get-renderer-info (renderer)
  "Allocate a new SDL_RendererInfo structure, fill it in with information
about the specified renderer, and return it."
  (let ((rinfo (make-renderer-info)))
    (check-rc (sdl-get-renderer-info renderer rinfo))
    rinfo))

;; TODO SDL_GetRendererOutputSize
(defun get-renderer-output-size (renderer)
  (niy "SDL_GetRendererOutputSize()"))


(defun update-texture (texture pixels &key rect width)
  "Use this function to update the given texture rectangle with new pixel data."
  (check-rc (sdl2-ffi.functions:sdl-update-texture texture
                                                        rect
                                                        pixels
                                                        width)))

(defun create-texture (renderer pixel-format access width height)
  "Use this function to create a texture for a rendering context."
  (sdl-collect
   (check-null (sdl-create-texture renderer
                                   (enum-value 'sdl-pixel-format pixel-format)
                                   (enum-value 'sdl-texture-access access)
                                   width height))
   (lambda (tex) (sdl-destroy-texture tex))))

(defun destroy-texture (texture)
  "Use this function to destroy the specified texture."
  (sdl-cancel-collect texture)
  (sdl-destroy-texture texture)
  (invalidate texture))

(defun lock-texture (texture &optional rect)
  "Use this function to lock a portion of the texture for write-only pixel access."
  (c-let ((pixels :pointer :free t)
          (pitch :int :free t))
    (check-rc (sdl-lock-texture texture rect (pixels &) (pitch &)))
    (values pixels pitch)))

(defun unlock-texture (texture)
  "Use this function to unlock a texture, uploading the changes to video memory, if needed. Warning: See Bug No. 1586 before using this function!"
  (sdl-unlock-texture texture))

(defun gl-bind-texture (texture)
  (c-with ((texw :float)
           (texh :float))
    (check-rc (sdl-gl-bind-texture texture (texw &) (texh &)))
    (values texw texh)))

(defun gl-unbind-texture (texture)
  (check-rc (sdl-gl-unbind-texture texture)))
