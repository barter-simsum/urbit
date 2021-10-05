import create from 'zustand';
import produce from 'immer';
import { useCallback, useEffect } from 'react';
import { omit, pick } from 'lodash';
import {
  Allies,
  Charge,
  ChargeUpdateInitial,
  scryAllies,
  scryAllyTreaties,
  scryCharges,
  scryDefaultAlly,
  Treaty,
  Docket,
  Treaties,
  chadIsRunning,
  AllyUpdateIni,
  TreatyUpdateIni,
  docketInstall,
  ChargeUpdate,
  kilnRevive,
  kilnSuspend
} from '@urbit/api';
import api from './api';
import { mockAllies, mockCharges, mockTreaties } from './mock-data';
import { fakeRequest, normalizeUrbitColor, useMockData } from './util';

export interface ChargeWithDesk extends Charge {
  desk: string;
}

export interface ChargesWithDesks {
  [ref: string]: ChargeWithDesk;
}

export interface DocketWithDesk extends Docket {
  desk: string;
}

interface DocketState {
  charges: ChargesWithDesks;
  treaties: Treaties;
  allies: Allies;
  defaultAlly: string | null;
  fetchCharges: () => Promise<void>;
  fetchDefaultAlly: () => Promise<void>;
  requestTreaty: (ship: string, desk: string) => Promise<Treaty>;
  fetchAllies: () => Promise<Allies>;
  fetchAllyTreaties: (ally: string) => Promise<Treaties>;
  toggleDocket: (desk: string) => Promise<void>;
  installDocket: (ship: string, desk: string) => Promise<number | void>;
  uninstallDocket: (desk: string) => Promise<number | void>;
}

const useDocketState = create<DocketState>((set, get) => ({
  defaultAlly: useMockData ? '~zod' : null,
  fetchDefaultAlly: async () => {
    const defaultAlly = await api.scry<string>(scryDefaultAlly);
    set({ defaultAlly });
  },
  fetchCharges: async () => {
    const charg = useMockData
      ? await fakeRequest(mockCharges)
      : (await api.scry<ChargeUpdateInitial>(scryCharges)).initial;

    const charges = Object.entries(charg).reduce((obj: ChargesWithDesks, [key, value]) => {
      // eslint-disable-next-line no-param-reassign
      obj[key] = normalizeDocket(value as ChargeWithDesk, key);
      return obj;
    }, {});

    set({ charges });
  },
  fetchAllies: async () => {
    const allies = useMockData ? mockAllies : (await api.scry<AllyUpdateIni>(scryAllies)).ini;
    set({ allies });
    return allies;
  },
  fetchAllyTreaties: async (ally: string) => {
    let treaties = useMockData
      ? mockTreaties
      : (await api.scry<TreatyUpdateIni>(scryAllyTreaties(ally))).ini;
    treaties = normalizeDockets(treaties);
    set((s) => ({ treaties: { ...s.treaties, ...treaties } }));
    return treaties;
  },
  requestTreaty: async (ship: string, desk: string) => {
    const { treaties } = get();
    if (useMockData) {
      set({ treaties: await fakeRequest(treaties) });
      return treaties[desk];
    }

    const key = `${ship}/${desk}`;
    if (key in treaties) {
      return treaties[key];
    }

    const result = await api.subscribeOnce('treaty', `/treaty/${key}`, 20000);
    const treaty = { ...normalizeDocket(result, desk), ship };
    set((state) => ({
      treaties: { ...state.treaties, [key]: treaty }
    }));
    return treaty;
  },
  installDocket: async (ship: string, desk: string) => {
    const treaty = get().treaties[`${ship}/${desk}`];
    if (!treaty) {
      throw new Error('Bad install');
    }
    set((state) => addCharge(state, desk, { ...treaty, chad: { install: null } }));
    if (useMockData) {
      await new Promise<void>((res) => setTimeout(() => res(), 10000));
      set((state) => addCharge(state, desk, { ...treaty, chad: { glob: null } }));
    }

    return api.poke(docketInstall(ship, desk));
  },
  uninstallDocket: async (desk: string) => {
    set((state) => delCharge(state, desk));
    if (useMockData) {
      return;
    }
    await api.poke({
      app: 'docket',
      mark: 'docket-uninstall',
      json: desk
    });
  },
  toggleDocket: async (desk: string) => {
    if (useMockData) {
      set(
        produce((draft) => {
          const charge = draft.charges[desk];
          charge.chad = chadIsRunning(charge.chad) ? { suspend: null } : { glob: null };
        })
      );
    }
    const { charges } = get();
    const charge = charges[desk];
    if (!charge) {
      return;
    }
    const suspended = 'suspend' in charge.chad;
    if (suspended) {
      await api.poke(kilnRevive(desk));
    } else {
      await api.poke(kilnSuspend(desk));
    }
  },
  treaties: useMockData ? normalizeDockets(mockTreaties) : {},
  charges: {},
  allies: useMockData ? mockAllies : {},
  set
}));

function normalizeDocket<T extends Docket>(docket: T, desk: string): T {
  return {
    ...docket,
    desk,
    color: normalizeUrbitColor(docket.color)
  };
}

function normalizeDockets<T extends Docket>(dockets: Record<string, T>): Record<string, T> {
  return Object.entries(dockets).reduce((obj: Record<string, T>, [key, value]) => {
    const [, desk] = key.split('/');
    // eslint-disable-next-line no-param-reassign
    obj[key] = normalizeDocket(value, desk);
    return obj;
  }, {});
}

function addCharge(state: DocketState, desk: string, charge: Charge) {
  return { charges: { ...state.charges, [desk]: normalizeDocket(charge as ChargeWithDesk, desk) } };
}

function delCharge(state: DocketState, desk: string) {
  return { charges: omit(state.charges, desk) };
}

api.subscribe({
  app: 'docket',
  path: '/charges',
  event: (data: ChargeUpdate) => {
    useDocketState.setState((state) => {
      if ('add-charge' in data) {
        const { desk, charge } = data['add-charge'];
        return addCharge(state, desk, charge);
      }

      if ('del-charge' in data) {
        const desk = data['del-charge'];
        return delCharge(state, desk);
      }

      return { charges: state.charges };
    });
  }
});

const selCharges = (s: DocketState) => {
  return s.charges;
};

export function useCharges() {
  return useDocketState(selCharges);
}

export function useCharge(desk: string) {
  return useDocketState(useCallback((state) => state.charges[desk], [desk]));
}

const selRequest = (s: DocketState) => s.requestTreaty;
export function useRequestDocket() {
  return useDocketState(selRequest);
}

const selAllies = (s: DocketState) => s.allies;
export function useAllies() {
  return useDocketState(selAllies);
}

export function useAllyTreaties(ship: string) {
  useEffect(() => {
    useDocketState.getState().fetchAllyTreaties(ship);
  }, [ship]);

  return useDocketState(
    useCallback(
      (s) => {
        const charter = s.allies[ship];
        return pick(s.treaties, ...(charter || []));
      },
      [ship]
    )
  );
}

export function useTreaty(host: string, desk: string) {
  return useDocketState(
    useCallback(
      (s) => {
        const ref = `${host}/${desk}`;
        return s.treaties[ref];
      },
      [host, desk]
    )
  );
}

export function allyForTreaty(ship: string, desk: string) {
  const ref = `${ship}/${desk}`;
  const { allies } = useDocketState.getState();
  const ally = Object.entries(allies).find(([, allied]) => allied.includes(ref))?.[0];
  return ally;
}

export const landscapeTreatyHost = import.meta.env.LANDSCAPE_HOST as string;

// xx useful for debugging
window.docket = useDocketState.getState;

if (useMockData) {
  window.desk = 'garden';
}

export default useDocketState;
