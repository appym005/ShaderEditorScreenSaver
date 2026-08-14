package de.markusfisch.android.shadereditor.service;

import android.opengl.GLSurfaceView;
import android.service.dreams.DreamService;

import de.markusfisch.android.shadereditor.app.ShaderEditorApp;
import de.markusfisch.android.shadereditor.database.DataRecords;
import de.markusfisch.android.shadereditor.database.DataSource;
import de.markusfisch.android.shadereditor.database.Database;
import de.markusfisch.android.shadereditor.widget.ShaderView;

/**
 * Android screen saver (DreamService) that renders the shader selected in
 * Shader Editor's "Set as screen saver" action.
 */
public class ShaderDreamService extends DreamService {
	private ShaderView view;

	@Override
	public void onAttachedToWindow() {
		super.onAttachedToWindow();
		setInteractive(false);
		setFullscreen(true);

		view = new ShaderView(this, GLSurfaceView.RENDERMODE_CONTINUOUSLY);
		setContentView(view);
		setShader();
	}

	@Override
	public void onDreamingStarted() {
		super.onDreamingStarted();
		if (view != null) {
			view.onResume();
		}
	}

	@Override
	public void onDreamingStopped() {
		if (view != null) {
			view.onPause();
		}
		super.onDreamingStopped();
	}

	@Override
	public void onDetachedFromWindow() {
		if (view != null) {
			view.onPause();
			view = null;
		}
		super.onDetachedFromWindow();
	}

	private void setShader() {
		DataSource dataSource = Database.getInstance(this).getDataSource();

		long shaderId = ShaderEditorApp.preferences.getScreensaverShader();
		DataRecords.Shader shader = dataSource.shader.getShader(shaderId);

		// If the saved shader no longer exists, safely fall back to another one.
		if (shader == null) {
			shader = dataSource.shader.getRandomShader();
			if (shader == null) {
				return;
			}
			ShaderEditorApp.preferences.setScreensaverShader(shader.id());
		}

		if (view != null) {
			view.getRenderer().setFragmentShader(
					shader.fragmentShader(),
					shader.quality());
		}
	}
}
