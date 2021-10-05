import { Poke, Scry } from '../lib';
import { Vats, Vat } from './types';
import _ from 'lodash';

export const getVats: Scry = {
  app: 'hood',
  path: '/kiln/vats'
};

/**
 * Install a foreign desk
 */
export function kilnInstall(
  ship: string,
  desk: string,
  local?: string
): Poke<any> {
  return {
    app: 'hood',
    mark: 'kiln-install',
    json: {
      ship,
      desk,
      local: local || desk
    }
  };
}

/**
 * Uninstall a desk
 */
export function kilnUninstall(
  desk: string
): Poke<any> {
  return {
    app: 'hood',
    mark: 'kiln-uninstall',
    json: desk
  };
}

export function kilnSuspend(
  desk: string
): Poke<any> {
  return {
    app: 'hood',
    mark: 'kiln-suspend',
    json: desk
  };
}

export function kilnRevive(
  desk: string
): Poke<any> {
  return {
    app: 'hood',
    mark: 'kiln-revive',
    json: desk
  };
}

export function kilnBump(force = false, except = [] as string[]) {
  return {
    app: 'hood',
    mark: 'kiln-bump',
    json: {
      force,
      except
    }
  };
}

export function kilnPause(desk: string) {
  return {
    app: 'hood',
    mark: 'kiln-pause',
    json: desk
  };
}

export function kilnResume(desk: string) {
  return {
    app: 'hood',
    mark: 'kiln-resume',
    json: desk
  };
}

export const scryLag: Scry = ({ app: 'hood', path: '/kiln/lag' });

export function getBlockers(vats: Vats): string[] {
  const blockers: string[] = [];
  const base = vats?.base;
  if(!base) {
    return blockers;
  }
  const blockedOn = base.arak.rail?.next?.[0]?.weft?.kelvin;
  if(!blockedOn) {
    return blockers;
  }
  _.forEach(_.omit(vats, 'base'), (vat, desk) => {
    // assuming only %zuse
    const kelvins = _.map((vat.arak.rail?.next || []), n => n.weft.kelvin);
    if(!(kelvins.includes(blockedOn))) {
      blockers.push(desk);
    }
  });

  return blockers;
}

export function getVatPublisher(vat: Vat): string | undefined {
  if (vat.arak.rail) {
    const { rail } = vat.arak;
    return (rail?.publisher || rail?.ship || undefined);
  }
  return undefined;
}
